require 'yaml'

describe 'compiled component' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/default.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/default/asg-v2.compiled.yaml") }

  context 'Resource SecurityGroupAsg' do

    let(:properties) { template["Resources"]["SecurityGroupAsg"]["Properties"] }

    it 'has property VpcId' do
      expect(properties["VpcId"]).to eq({"Ref"=>"VPCId"})
    end

    it 'has property GroupDescription' do
      expect(properties["GroupDescription"]).to eq({"Fn::Sub"=>"${EnvironmentName}-asg-v2"})
    end


    it 'has property Tags' do
      expect(properties["Tags"]).to eq([
        {"Key"=>"Name", "Value"=>{"Fn::Sub"=>"${EnvironmentName}-asg-v2"}}, 
        {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, 
        {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
    end

  end

  context 'Resource Role' do

    let(:properties) { template["Resources"]["Role"]["Properties"] }

    it 'has property Path' do
      expect(properties["Path"]).to eq("/")
    end

    it 'has property AssumeRolePolicyDocument' do
      expect(properties["AssumeRolePolicyDocument"]).to eq({"Version"=>"2012-10-17", "Statement"=>[{"Effect"=>"Allow", "Principal"=>{"Service"=>"ec2.amazonaws.com"}, "Action"=>"sts:AssumeRole"}]})
    end

    # it 'has property Policies' do
    #   expect(properties["Policies"]).to eq([{"PolicyName"=>"ecs-container-instance", "PolicyDocument"=>{"Statement"=>[{"Sid"=>"ecscontainerinstance", "Action"=>["ecs:CreateCluster", "ecs:DeregisterContainerInstance", "ecs:DiscoverPollEndpoint", "ecs:Poll", "ecs:RegisterContainerInstance", "ecs:StartTelemetrySession", "ecs:Submit*", "ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "logs:CreateLogStream", "logs:PutLogEvents"], "Resource"=>["*"], "Effect"=>"Allow"}]}}, {"PolicyName"=>"ecs-service-scheduler", "PolicyDocument"=>{"Statement"=>[{"Sid"=>"ecsservicescheduler", "Action"=>["ec2:AuthorizeSecurityGroupIngress", "ec2:Describe*", "elasticloadbalancing:DeregisterInstancesFromLoadBalancer", "elasticloadbalancing:DeregisterTargets", "elasticloadbalancing:Describe*", "elasticloadbalancing:RegisterInstancesWithLoadBalancer", "elasticloadbalancing:RegisterTargets"], "Resource"=>["*"], "Effect"=>"Allow"}]}}])
    # end

    # it 'has property Tags' do
    #   expect(properties["Tags"]).to eq([
    #     {"Key"=>"Name", "Value"=>{"Fn::Sub"=>"${EnvironmentName}-ecs-v2"}}, 
    #     {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, 
    #     {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
    # end

  end

  context 'Resource InstanceProfile' do

    let(:properties) { template["Resources"]["InstanceProfile"]["Properties"] }

    it 'has property Path' do
      expect(properties["Path"]).to eq("/")
    end

    it 'has property Roles' do
      expect(properties["Roles"]).to eq([{"Ref"=>"Role"}])
    end

  end

  context 'Resource LaunchTemplate' do

    let(:properties) { template["Resources"]["LaunchTemplate"]["Properties"] }
    let(:userdata) { properties["LaunchTemplateData"]["UserData"]["Fn::Base64"]["Fn::Sub"] }

    it 'has property LaunchTemplateData' do
      expect(properties["LaunchTemplateData"]).to be_kind_of(Hash)
    end

    it 'has linux userdata' do
      expect(userdata).to include("#!/bin/bash")
    end

  end

  context 'Resource AutoScaleGroup' do

    let(:properties) { template["Resources"]["AutoScaleGroup"]["Properties"] }

    it 'has property DesiredCapacity' do
      expect(properties["DesiredCapacity"]).to eq({"Ref"=>"AsgDesired"})
    end

    it 'has property MinSize' do
      expect(properties["MinSize"]).to eq({"Ref"=>"AsgMin"})
    end

    it 'has property MaxSize' do
      expect(properties["MaxSize"]).to eq({"Ref"=>"AsgMax"})
    end

    it 'has property VPCZoneIdentifier' do
      expect(properties["VPCZoneIdentifier"]).to eq({"Ref"=>"Subnets"})
    end

    it 'has property LaunchTemplate' do
      expect(properties["LaunchTemplate"]).to eq({"LaunchTemplateId"=>{"Ref"=>"LaunchTemplate"}, "Version"=>{"Fn::GetAtt"=>["LaunchTemplate", "LatestVersionNumber"]}})
    end

    it 'has property Tags' do
      expect(properties["Tags"]).to eq([
        {"Key"=>"Name", "Value"=>{"Fn::Sub"=>"${EnvironmentName}-asg-v2"}, "PropagateAtLaunch"=>false}, 
        {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}, "PropagateAtLaunch"=>false}, 
        {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}, "PropagateAtLaunch"=>false}])
    end

  end

end
