require 'yaml'

describe 'compiled component asg-v2' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/asg_disable_policies.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/asg_disable_policies/asg-v2.compiled.yaml") }
  
  context "Resource" do

    
    context "SecurityGroupAsg" do
      let(:resource) { template["Resources"]["SecurityGroupAsg"] }

      it "is of type AWS::EC2::SecurityGroup" do
          expect(resource["Type"]).to eq("AWS::EC2::SecurityGroup")
      end
      
      it "to have property VpcId" do
          expect(resource["Properties"]["VpcId"]).to eq({"Ref"=>"VPCId"})
      end
      
      it "to have property GroupDescription" do
          expect(resource["Properties"]["GroupDescription"]).to eq({"Fn::Sub"=>"${EnvironmentName}-asg-v2"})
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>{"Fn::Sub"=>"${EnvironmentName}-asg-v2"}}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
    context "Role" do
      let(:resource) { template["Resources"]["Role"] }

      it "is of type AWS::IAM::Role" do
          expect(resource["Type"]).to eq("AWS::IAM::Role")
      end
      
      it "to have property Path" do
          expect(resource["Properties"]["Path"]).to eq("/")
      end
      
      it "to have property AssumeRolePolicyDocument" do
          expect(resource["Properties"]["AssumeRolePolicyDocument"]).to eq({"Version"=>"2012-10-17", "Statement"=>[{"Effect"=>"Allow", "Principal"=>{"Service"=>"ec2.amazonaws.com"}, "Action"=>"sts:AssumeRole"}]})
      end
      
      it "to have property Policies" do
          expect(resource["Properties"]["Policies"]).to eq([{"PolicyName"=>"loadbalancer-manage", "PolicyDocument"=>{"Statement"=>[{"Sid"=>"loadbalancermanage", "Action"=>["ec2:AuthorizeSecurityGroupIngress", "elasticloadbalancing:DeregisterInstancesFromLoadBalancer", "elasticloadbalancing:DeregisterTargets", "elasticloadbalancing:Describe*", "elasticloadbalancing:RegisterInstancesWithLoadBalancer", "elasticloadbalancing:RegisterTargets"], "Resource"=>["*"], "Effect"=>"Allow"}]}}, {"PolicyName"=>"ec2-describe", "PolicyDocument"=>{"Statement"=>[{"Sid"=>"ec2describe", "Action"=>["ec2:Describe*"], "Resource"=>["*"], "Effect"=>"Allow"}]}}])
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>{"Fn::Sub"=>"${EnvironmentName}-asg-v2"}}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
    context "InstanceProfile" do
      let(:resource) { template["Resources"]["InstanceProfile"] }

      it "is of type AWS::IAM::InstanceProfile" do
          expect(resource["Type"]).to eq("AWS::IAM::InstanceProfile")
      end
      
      it "to have property Path" do
          expect(resource["Properties"]["Path"]).to eq("/")
      end
      
      it "to have property Roles" do
          expect(resource["Properties"]["Roles"]).to eq([{"Ref"=>"Role"}])
      end
      
    end
    
    context "LaunchTemplate" do
      let(:resource) { template["Resources"]["LaunchTemplate"] }

      it "is of type AWS::EC2::LaunchTemplate" do
          expect(resource["Type"]).to eq("AWS::EC2::LaunchTemplate")
      end
      
      it "to have property LaunchTemplateData" do
          expect(resource["Properties"]["LaunchTemplateData"]).to eq({"SecurityGroupIds"=>[{"Ref"=>"SecurityGroupAsg"}], "TagSpecifications"=>[{"ResourceType"=>"instance", "Tags"=>[{"Key"=>"Name", "Value"=>{"Fn::Sub"=>"${EnvironmentName}-asg-v2"}}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}, {"Key"=>"Role", "Value"=>{"Fn::Sub"=>"${RoleName}"}}, {"Key"=>"Name", "Value"=>{"Fn::Sub"=>"${EnvironmentName}-asg-xx"}}]}, {"ResourceType"=>"volume", "Tags"=>[{"Key"=>"Name", "Value"=>{"Fn::Sub"=>"${EnvironmentName}-asg-v2"}}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}, {"Key"=>"Role", "Value"=>{"Fn::Sub"=>"${RoleName}"}}, {"Key"=>"Name", "Value"=>{"Fn::Sub"=>"${EnvironmentName}-asg-xx"}}]}], "UserData"=>{"Fn::Base64"=>{"Fn::Sub"=>"#!/bin/bash\nhostname ${EnvironmentName}-${RoleName}-`/opt/aws/bin/ec2-metadata --instance-id|/usr/bin/awk '{print $2}'`\nsed '/HOSTNAME/d' /etc/sysconfig/network > /tmp/network && mv -f /tmp/network /etc/sysconfig/network && echo \"HOSTNAME=${EnvironmentName}-`/opt/aws/bin/ec2-metadata --instance-id|/usr/bin/awk '{print $2}'`\" >>/etc/sysconfig/network && /etc/init.d/network restart\n"}}, "IamInstanceProfile"=>{"Name"=>{"Ref"=>"InstanceProfile"}}, "KeyName"=>{"Fn::If"=>["KeyPairSet", {"Ref"=>"KeyPair"}, {"Ref"=>"AWS::NoValue"}]}, "ImageId"=>{"Ref"=>"Ami"}, "InstanceType"=>{"Ref"=>"InstanceType"}, "InstanceMarketOptions"=>{"Fn::If"=>["SpotEnabled", {"MarketType"=>"spot", "SpotOptions"=>{"SpotInstanceType"=>"one-time"}}, {"Ref"=>"AWS::NoValue"}]}})
      end
      
    end
    
    context "AutoScaleGroup" do
      let(:resource) { template["Resources"]["AutoScaleGroup"] }

      it "is of type AWS::AutoScaling::AutoScalingGroup" do
          expect(resource["Type"]).to eq("AWS::AutoScaling::AutoScalingGroup")
      end
      
      it "to have property DesiredCapacity" do
          expect(resource["Properties"]["DesiredCapacity"]).to eq({"Ref"=>"AsgDesired"})
      end
      
      it "to have property MinSize" do
          expect(resource["Properties"]["MinSize"]).to eq({"Ref"=>"AsgMin"})
      end
      
      it "to have property MaxSize" do
          expect(resource["Properties"]["MaxSize"]).to eq({"Ref"=>"AsgMax"})
      end
      
      it "to have property VPCZoneIdentifier" do
          expect(resource["Properties"]["VPCZoneIdentifier"]).to eq({"Ref"=>"SubnetIds"})
      end
      
      it "to have property LaunchTemplate" do
          expect(resource["Properties"]["LaunchTemplate"]).to eq({"LaunchTemplateId"=>{"Ref"=>"LaunchTemplate"}, "Version"=>{"Fn::GetAtt"=>["LaunchTemplate", "LatestVersionNumber"]}})
      end
      
      it "to have property HealthCheckGracePeriod" do
          expect(resource["Properties"]["HealthCheckGracePeriod"]).to eq({"Ref"=>"HealthCheckGracePeriod"})
      end
      
      it "to have property HealthCheckType" do
          expect(resource["Properties"]["HealthCheckType"]).to eq({"Ref"=>"HealthCheckType"})
      end
      
      it "to have property TerminationPolicies" do
          expect(resource["Properties"]["TerminationPolicies"]).to eq(["Default"])
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>{"Fn::Sub"=>"${EnvironmentName}-asg-v2"}, "PropagateAtLaunch"=>false}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}, "PropagateAtLaunch"=>false}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}, "PropagateAtLaunch"=>false}])
      end
      
    end
    
    context "ScaleUpAlarm" do
      let(:resource) { template["Resources"]["ScaleUpAlarm"] }

      it "is of type AWS::CloudWatch::Alarm" do
          expect(resource["Type"]).to eq("AWS::CloudWatch::Alarm")
      end
      
      it "to have property AlarmDescription" do
          expect(resource["Properties"]["AlarmDescription"]).to eq({"Fn::Sub"=>"${EnvironmentName asg-v2 scale up alarm"})
      end
      
      it "to have property MetricName" do
          expect(resource["Properties"]["MetricName"]).to eq("CPUUtilization")
      end
      
      it "to have property Namespace" do
          expect(resource["Properties"]["Namespace"]).to eq("AWS/EC2")
      end
      
      it "to have property Statistic" do
          expect(resource["Properties"]["Statistic"]).to eq("Average")
      end
      
      it "to have property Period" do
          expect(resource["Properties"]["Period"]).to eq("60")
      end
      
      it "to have property EvaluationPeriods" do
          expect(resource["Properties"]["EvaluationPeriods"]).to eq("5")
      end
      
      it "to have property Threshold" do
          expect(resource["Properties"]["Threshold"]).to eq("70")
      end
      
      it "to have property AlarmActions" do
          expect(resource["Properties"]["AlarmActions"]).to eq([{"Ref"=>"ScaleUpPolicy"}])
      end
      
      it "to have property ComparisonOperator" do
          expect(resource["Properties"]["ComparisonOperator"]).to eq("GreaterThanThreshold")
      end
      
      it "to have property Dimensions" do
          expect(resource["Properties"]["Dimensions"]).to eq([{"Name"=>"AutoScalingGroupName", "Value"=>{"Ref"=>"AutoScaleGroup"}}])
      end
      
    end
    
    context "ScaleDownAlarm" do
      let(:resource) { template["Resources"]["ScaleDownAlarm"] }

      it "is of type AWS::CloudWatch::Alarm" do
          expect(resource["Type"]).to eq("AWS::CloudWatch::Alarm")
      end
      
      it "to have property AlarmDescription" do
          expect(resource["Properties"]["AlarmDescription"]).to eq({"Fn::Sub"=>"${EnvironmentName asg-v2 scale down alarm"})
      end
      
      it "to have property MetricName" do
          expect(resource["Properties"]["MetricName"]).to eq("CPUUtilization")
      end
      
      it "to have property Namespace" do
          expect(resource["Properties"]["Namespace"]).to eq("AWS/EC2")
      end
      
      it "to have property Statistic" do
          expect(resource["Properties"]["Statistic"]).to eq("Average")
      end
      
      it "to have property Period" do
          expect(resource["Properties"]["Period"]).to eq("60")
      end
      
      it "to have property EvaluationPeriods" do
          expect(resource["Properties"]["EvaluationPeriods"]).to eq("10")
      end
      
      it "to have property Threshold" do
          expect(resource["Properties"]["Threshold"]).to eq("40")
      end
      
      it "to have property AlarmActions" do
          expect(resource["Properties"]["AlarmActions"]).to eq([{"Ref"=>"ScaleDownPolicy"}])
      end
      
      it "to have property ComparisonOperator" do
          expect(resource["Properties"]["ComparisonOperator"]).to eq("LessThanThreshold")
      end
      
      it "to have property Dimensions" do
          expect(resource["Properties"]["Dimensions"]).to eq([{"Name"=>"AutoScalingGroupName", "Value"=>{"Ref"=>"AutoScaleGroup"}}])
      end
      
    end
    
    context "ScaleUpPolicy" do
      let(:resource) { template["Resources"]["ScaleUpPolicy"] }

      it "is of type AWS::AutoScaling::ScalingPolicy" do
          expect(resource["Type"]).to eq("AWS::AutoScaling::ScalingPolicy")
      end
      
      it "to have property AdjustmentType" do
          expect(resource["Properties"]["AdjustmentType"]).to eq("ChangeInCapacity")
      end
      
      it "to have property AutoScalingGroupName" do
          expect(resource["Properties"]["AutoScalingGroupName"]).to eq({"Ref"=>"AutoScaleGroup"})
      end
      
      it "to have property Cooldown" do
          expect(resource["Properties"]["Cooldown"]).to eq("300")
      end
      
      it "to have property ScalingAdjustment" do
          expect(resource["Properties"]["ScalingAdjustment"]).to eq(1)
      end
      
    end
    
    context "ScaleDownPolicy" do
      let(:resource) { template["Resources"]["ScaleDownPolicy"] }

      it "is of type AWS::AutoScaling::ScalingPolicy" do
          expect(resource["Type"]).to eq("AWS::AutoScaling::ScalingPolicy")
      end
      
      it "to have property AdjustmentType" do
          expect(resource["Properties"]["AdjustmentType"]).to eq("ChangeInCapacity")
      end
      
      it "to have property AutoScalingGroupName" do
          expect(resource["Properties"]["AutoScalingGroupName"]).to eq({"Ref"=>"AutoScaleGroup"})
      end
      
      it "to have property Cooldown" do
          expect(resource["Properties"]["Cooldown"]).to eq("300")
      end
      
      it "to have property ScalingAdjustment" do
          expect(resource["Properties"]["ScalingAdjustment"]).to eq(-1)
      end
      
    end
    
  end

end