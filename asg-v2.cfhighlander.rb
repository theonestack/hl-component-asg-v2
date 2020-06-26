CfhighlanderTemplate do

  DependsOn 'lib-iam@0.1.0'
  DependsOn 'lib-ec2@0.1.0'

  Parameters do
    ComponentParam 'EnvironmentName', 'dev', isGlobal: true
    
    ComponentParam 'EnvironmentType', 'development', 
        allowedValues: ['development','production'], isGlobal: true

    ComponentParam 'RoleName'
    
    ComponentParam 'VPCId', type: 'AWS::EC2::VPC::Id'
    ComponentParam 'KeyPair', ''
    ComponentParam 'Ami', type: 'AWS::EC2::Image::Id'
      
    ComponentParam 'InstanceType', 't3.small'

    ComponentParam 'Spot', 'false', allowedValues: ['true','false']

    ComponentParam 'SubnetIds', type: 'CommaDelimitedList'

    ComponentParam 'AsgDesired', '1'
    ComponentParam 'AsgMin', '1'
    ComponentParam 'AsgMax', '2'
    ComponentParam 'EnableScaling', 'false', allowedValues: ['true','false']
    ComponentParam 'EnableTargetTrackingScaling', 'false', allowedValues: ['true','false']

    ComponentParam 'HealthCheckType', 'EC2', allowedValues: ['EC2','ELB'] 
    ComponentParam 'HealthCheckGracePeriod', '500'

    targetgroups.each do |tg|
      ComponentParam tg
    end if defined? targetgroups

  end

end
