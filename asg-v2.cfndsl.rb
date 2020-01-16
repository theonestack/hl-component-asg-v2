CloudFormation do
  
  asg_tags = []
  asg_tags << { Key: 'Name', Value: FnSub("${EnvironmentName}-#{external_parameters[:component_name]}") }
  asg_tags << { Key: 'Environment', Value: Ref(:EnvironmentName) }
  asg_tags << { Key: 'EnvironmentType', Value: Ref(:EnvironmentType) }

  Condition(:SpotEnabled, FnEquals(Ref(:Spot), 'true'))
  Condition(:KeyPairSet, FnNot(FnEquals(Ref(:KeyPair), '')))
    
  ip_blocks = external_parameters.fetch(:ip_blocks, {})
  security_group_rules = external_parameters.fetch(:security_group_rules, [])
  
  EC2_SecurityGroup(:SecurityGroupAsg) {
    VpcId Ref(:VPCId)
    GroupDescription FnSub("${EnvironmentName}-#{external_parameters[:component_name]}")
    
    if security_group_rules.any?
      SecurityGroupIngress generate_security_group_rules(security_group_rules,ip_blocks)
    end
    Tags asg_tags
  }

  Output(:SecurityGroup) {
    Value(Ref(:SecurityGroupAsg))
    Export FnSub("${EnvironmentName}-#{external_parameters[:component_name]}-SecurityGroup")
  }
  
  IAM_Role(:Role) {
    Path '/'
    AssumeRolePolicyDocument service_assume_role_policy('ec2')
    Policies iam_role_policies(external_parameters[:iam_policies])
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

  AutoScaling_AutoScalingGroup(:AutoScaleGroup) {
    UpdatePolicy(:AutoScalingRollingUpdate, {
      "MinInstancesInService" => asg_update_policy['min'],
      "MaxBatchSize"          => asg_update_policy['batch_size'],
      "SuspendProcesses"      => asg_update_policy['suspend']
    })
    UpdatePolicy(:AutoScalingScheduledAction, {
      IgnoreUnmodifiedGroupSizeProperties: true
    })
    Cooldown cool_down unless cool_down.nil?
    DesiredCapacity Ref(:AsgDesired)
    MinSize Ref(:AsgMin)
    MaxSize Ref(:AsgMax)
    VPCZoneIdentifier Ref(:SubnetIds)
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
