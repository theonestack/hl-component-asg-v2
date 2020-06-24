CloudFormation do
  
  export = external_parameters.fetch(:export_name, external_parameters[:component_name])

  asg_tags = []
  asg_tags << { Key: 'Name', Value: FnSub("${EnvironmentName}-#{external_parameters[:component_name]}") }
  asg_tags << { Key: 'Environment', Value: Ref(:EnvironmentName) }
  asg_tags << { Key: 'EnvironmentType', Value: Ref(:EnvironmentType) }

  Condition(:SpotEnabled, FnEquals(Ref(:Spot), 'true'))
  Condition(:KeyPairSet, FnNot(FnEquals(Ref(:KeyPair), '')))
    
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
    SecurityGroupIds: [ Ref(:SecurityGroupAsg) ],
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

  suspend = asg_update_policy.has_key?('override_suspend') ? asg_update_policy['override_suspend'] : asg_update_policy['suspend']

  if defined?(asg_scaling)

    if asg_scaling.has_key?('up')

      default_alarm = {}
      default_alarm['statistic'] = 'Average'
      default_alarm['cooldown'] = '60'
      default_alarm['evaluation_periods'] = '5' 
      default_alarm['MetricName'] = 'CPUReservation')
      CloudWatch_Alarm(:ServiceScaleUpAlarm) {
        Condition 'IsScalingEnabled'
        AlarmDescription FnJoin(' ', [Ref('EnvironmentName'), "#{component_name} scale up alarm"])
        MetricName asg_scaling['up']['metric_name'] || default_alarm['MetricName']
        Namespace asg_scaling['up']['namespace']
        Statistic asg_scaling['up']['statistic'] || default_alarm['statistic']
        Period (asg_scaling['up']['cooldown'] || default_alarm['cooldown']).to_s
        EvaluationPeriods asg_scaling['up']['evaluation_periods'].to_s
        Threshold asg_scaling['up']['threshold'].to_s
        AlarmActions [Ref(:ScaleUpPolicy)]
        ComparisonOperator 'GreaterThanThreshold'
        Dimensions asg_scaling['up']['dimensions']
      }   

      CloudWatch_Alarm(:ServiceScaleDownAlarm) {
        Condition 'IsScalingEnabled'
        AlarmDescription FnJoin(' ', [Ref('EnvironmentName'), "#{component_name} scale down alarm"])
        MetricName asg_scaling['up']['metric_name'] || default_alarm['MetricName']
        Namespace asg_scaling['down']['namespace']
        Statistic asg_scaling['down']['statistic'] || default_alarm['statistic']
        Period (asg_scaling['down']['cooldown'] || default_alarm['cooldown']).to_s
        EvaluationPeriods asg_scaling['down']['evaluation_periods'].to_s
        Threshold asg_scaling['down']['threshold'].to_s
        AlarmActions [Ref(:ScaleDownPolicy)]
        ComparisonOperator 'LessThanThreshold'
        Dimensions asg_scaling['down']['dimensions']
      }   
    end

    Resource("ScaleUpPolicy") {
      Condition 'IsScalingEnabled'
      Type 'AWS::AutoScaling::ScalingPolicy'
      Property('AdjustmentType', 'ChangeInCapacity')
      Property('AutoScalingGroupName', Ref('AutoScaleGroup'))
      Property('Cooldown','300')
      Property('ScalingAdjustment', asg_scaling['up']['adjustment'])
    }

    Resource("ScaleDownPolicy") {
      Condition 'IsScalingEnabled'
      Type 'AWS::AutoScaling::ScalingPolicy'
      Property('AdjustmentType', 'ChangeInCapacity')
      Property('AutoScalingGroupName', Ref('AutoScaleGroup'))
      Property('Cooldown','300')
      Property('ScalingAdjustment', asg_scaling['down']['adjustment'])
    }
  end
  AutoScaling_AutoScalingGroup(:AutoScaleGroup) {
    CreationPolicy(:AutoScalingCreationPolicy, {
      "MinSuccessfulInstancesPercent" => asg_create_policy['min_successful']
    })
    CreationPolicy(:ResourceSignal, {
      "Count" => asg_create_policy['count'],
      "Timeout" => asg_create_policy['timeout']
    })
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

end
