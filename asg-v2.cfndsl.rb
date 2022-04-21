CloudFormation do
  
  export = external_parameters.fetch(:export_name, external_parameters[:component_name])

  asg_tags = []
  asg_tags << { Key: 'Name', Value: FnSub("${EnvironmentName}-#{external_parameters[:component_name]}") }
  asg_tags << { Key: 'Environment', Value: Ref(:EnvironmentName) }
  asg_tags << { Key: 'EnvironmentType', Value: Ref(:EnvironmentType) }

  Condition(:SpotEnabled, FnEquals(Ref(:Spot), 'true'))
  Condition(:KeyPairSet, FnNot(FnEquals(Ref(:KeyPair), '')))
  Condition('IsScalingEnabled', FnEquals(Ref('EnableScaling'), 'true'))
  Condition('IsTargetTrackingScalingEnabled', FnEquals(Ref('EnableTargetTrackingScaling'), 'true')) 
  
  ip_blocks = external_parameters.fetch(:ip_blocks, {})
  security_group_rules = external_parameters.fetch(:security_group_rules, [])

  EC2_SecurityGroup(:SecurityGroupAsg) do
    VpcId Ref('VPCId')
    GroupDescription FnSub("${EnvironmentName}-#{external_parameters[:component_name]}")
    Tags asg_tags
    Metadata({
      cfn_nag: {
        rules_to_suppress: [
          { id: 'F1000', reason: 'ignore egress for now' }
        ]
      }
    })
  end
  Output(:SecurityGroup) {
    Value(Ref(:SecurityGroupAsg))
    Export FnSub("${EnvironmentName}-#{export}-SecurityGroup")
  }

  ingress_rules = external_parameters.fetch(:ingress_rules, [])
  ingress_rules.each_with_index do |ingress_rule, i|
    EC2_SecurityGroupIngress("IngressRule#{i+1}") do
      Description ingress_rule['desc'] if ingress_rule.has_key?('desc')
      GroupId ingress_rule.has_key?('dest_sg') ? ingress_rule['dest_sg'] : Ref(:SecurityGroupAsg)
      SourceSecurityGroupId ingress_rule.has_key?('source_sg') ? ingress_rule['source_sg'] :  Ref(:SecurityGroupAsg)
      IpProtocol ingress_rule.has_key?('protocol') ? ingress_rule['protocol'] : 'tcp'
      FromPort ingress_rule['from']
      ToPort ingress_rule.has_key?('to') ? ingress_rule['to'] : ingress_rule['from']
    end
  end

  managed_iam_policies = external_parameters.fetch(:managed_iam_policies, [])
  
  IAM_Role(:Role) {
    Path '/'
    AssumeRolePolicyDocument service_assume_role_policy('ec2')
    Policies iam_role_policies(external_parameters[:iam_policies])
    ManagedPolicyArns managed_iam_policies if managed_iam_policies.any?
    Tags asg_tags
    Metadata({
      cfn_nag: {
        rules_to_suppress: [
          { id: 'F3', reason: 'ignore describe* for now' }
        ]
      }
    })
  }
    
  InstanceProfile(:InstanceProfile) {
    Path '/'
    Roles [Ref(:Role)]
  }
  
  operating_system = "#{external_parameters.fetch(:operating_system, 'linux')}_user_data"
  instance_userdata = external_parameters.fetch(operating_system.to_sym, 'linux')
    
  asg_instance_tags = asg_tags.map(&:clone)
  asg_instance_tags.push({ Key: 'Role', Value: FnSub('${RoleName}') })
  asg_instance_tags.push({ Key: 'Name', Value: FnSub("${EnvironmentName}-asg-xx") })
  
  instance_tags = external_parameters.fetch(:instance_tags, {})
  asg_instance_tags.push(*instance_tags.map {|k,v| {Key: k, Value: FnSub(v)}})
  
  template_data = {
    SecurityGroupIds: external_parameters.fetch(:security_groups, []),
    TagSpecifications: [
      { ResourceType: 'instance', Tags: asg_instance_tags },
      { ResourceType: 'volume', Tags: asg_instance_tags }
    ],
    UserData: FnBase64(FnSub(instance_userdata)),
    IamInstanceProfile: { Name: Ref(:InstanceProfile) },
    KeyName: FnIf(:KeyPairSet, Ref(:KeyPair), Ref('AWS::NoValue')),
    ImageId: Ref(:Ami),
    InstanceType: Ref(:InstanceType)
  }

  spot_options = {
    MarketType: 'spot',
    SpotOptions: {
      SpotInstanceType: 'one-time',
    }
  }
  template_data[:InstanceMarketOptions] = FnIf(:SpotEnabled, spot_options, Ref('AWS::NoValue'))

  volumes = external_parameters.fetch(:volumes, {})
  if volumes.any?
    template_data[:BlockDeviceMappings] = volumes
  end
    
  EC2_LaunchTemplate(:LaunchTemplate) {
    LaunchTemplateData(template_data)
  }

  lanuch_asg_tags = asg_tags.map(&:clone)
  asg_targetgroups = []
  targetgroups = external_parameters.fetch(:targetgroups, [])
  targetgroups.each {|tg| asg_targetgroups << Ref(tg)}
  asg_update_policy = external_parameters[:asg_update_policy]
  cool_down = external_parameters.fetch(:cool_down, nil)

  if asg_update_policy
    suspend = asg_update_policy.has_key?('override_suspend') ? asg_update_policy['override_suspend'] : asg_update_policy['suspend']
  end
 
  AutoScaling_AutoScalingGroup(:AutoScaleGroup) {
    if asg_create_policy
      CreationPolicy(:AutoScalingCreationPolicy, {
        "MinSuccessfulInstancesPercent" => asg_create_policy['min_successful']
      })
      CreationPolicy(:ResourceSignal, {
        "Count" => asg_create_policy['count'],
        "Timeout" => asg_create_policy['timeout']
      })
    end
    if asg_update_policy
      UpdatePolicy(:AutoScalingRollingUpdate, {
        "MinInstancesInService" => asg_update_policy['min'],
        "MaxBatchSize"          => asg_update_policy['batch_size'],
        "SuspendProcesses"      => suspend,
        "PauseTime"             => asg_update_policy['pause_time'],
        "WaitOnResourceSignals" => asg_update_policy['wait_on_signals']
      })
      UpdatePolicy(:AutoScalingScheduledAction, {
        IgnoreUnmodifiedGroupSizeProperties: true
      })
    end
    Cooldown cool_down unless cool_down.nil?
    DesiredCapacity Ref(:AsgDesired)
    MinSize Ref(:AsgMin)
    MaxSize Ref(:AsgMax)
    VPCZoneIdentifiers Ref(:SubnetIds)
    LaunchTemplate({
      LaunchTemplateId: Ref(:LaunchTemplate),
      Version: FnGetAtt(:LaunchTemplate, :LatestVersionNumber)
    })
    TargetGroupARNs asg_targetgroups if asg_targetgroups.any?
    HealthCheckGracePeriod Ref('HealthCheckGracePeriod')
    HealthCheckType Ref('HealthCheckType')
    TerminationPolicies external_parameters[:termination_policies]
    Tags lanuch_asg_tags.each {|tag| tag[:PropagateAtLaunch]=false}
  }

  Output(:AutoScalingGroupName) {
    Value(Ref(:AutoScaleGroup))
    Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-AutoScalingGroupName")
  }

  asg_scaling = external_parameters.fetch(:asg_scaling, {})
  scale_up = asg_scaling.fetch('up', {})
  scale_down = asg_scaling.fetch('down', {})
  asg_dimensions = [{Name: 'AutoScalingGroupName', Value: Ref('AutoScaleGroup')}]

  CloudWatch_Alarm(:ScaleUpAlarm) {
    Condition 'IsScalingEnabled'
    AlarmDescription FnSub(scale_up.fetch('desc', "${EnvironmentName #{component_name} scale up alarm"))
    MetricName scale_up.fetch('metric_name', 'CPUUtilization')
    Namespace scale_up.fetch('namespace', 'AWS/EC2')
    Statistic scale_up.fetch('statistic', 'Average')
    Period scale_up.fetch('period', '60').to_s
    EvaluationPeriods scale_up.fetch('evaluation_periods', '5').to_s
    Threshold scale_up.fetch('threshold', '70').to_s
    AlarmActions [Ref(:ScaleUpPolicy)]
    ComparisonOperator scale_up.fetch('operator', 'GreaterThanThreshold')
    Dimensions scale_up.fetch('dimensions', asg_dimensions)
  }

  CloudWatch_Alarm(:ScaleDownAlarm) {
    Condition 'IsScalingEnabled'
    AlarmDescription FnSub(scale_down.fetch('desc', "${EnvironmentName #{component_name} scale down alarm"))
    MetricName scale_down.fetch('metric_name', 'CPUUtilization')
    Namespace scale_down.fetch('namespace', 'AWS/EC2')
    Statistic scale_down.fetch('statistic', 'Average')
    Period scale_down.fetch('period', '60').to_s
    EvaluationPeriods scale_down.fetch('evaluation_periods', '10').to_s
    Threshold scale_down.fetch('threshold', '40').to_s
    AlarmActions [Ref(:ScaleDownPolicy)]
    ComparisonOperator scale_down.fetch('operator', 'LessThanThreshold')
    Dimensions scale_down.fetch('dimensions', asg_dimensions)
  }

  step_up_scaling = scale_up.fetch('step_adjustments', [])

  AutoScaling_ScalingPolicy(:ScaleUpPolicy) {
    Condition 'IsScalingEnabled'
    AdjustmentType scale_up.fetch('adjustment_type', 'ChangeInCapacity')
    AutoScalingGroupName Ref('AutoScaleGroup')
    if step_up_scaling.any?
      PolicyType 'StepScaling'
      StepAdjustments step_up_scaling
      EstimatedInstanceWarmup scale_up.fetch('warmup', 300).to_i
    else
      Cooldown scale_up.fetch('cooldown', '300').to_s
      ScalingAdjustment scale_up.fetch('adjustment', 1)
    end
  }

  step_down_scaling = scale_down.fetch('step_adjustments', [])

  AutoScaling_ScalingPolicy(:ScaleDownPolicy) {
    Condition 'IsScalingEnabled'
    AdjustmentType 'ChangeInCapacity'
    AutoScalingGroupName Ref('AutoScaleGroup')
    if step_down_scaling.any?
      PolicyType 'StepScaling'
      StepAdjustments step_down_scaling
      EstimatedInstanceWarmup scale_up.fetch('warmup', 300).to_i
    else
      Cooldown scale_up.fetch('cooldown', '300').to_s
      ScalingAdjustment scale_down.fetch('adjustment', -1)
    end
  }

  target_tracking = external_parameters.fetch(:target_tracking, {})

  target_tracking.each do |name,config|
    AutoScaling_ScalingPolicy(name) {
      Condition 'IsTargetTrackingScalingEnabled'
      AutoScalingGroupName Ref('AutoScaleGroup')
      PolicyType 'TargetTrackingScaling'
      TargetTrackingConfiguration config
      EstimatedInstanceWarmup scale_up.fetch('warmup', 60).to_i
    }
  end      

end
