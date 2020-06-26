require 'yaml'

describe 'compiled component' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/asg_scaling_tracking.test.yaml")).to be_truthy
    end      
  end

  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/asg_scaling_tracking/asg-v2.compiled.yaml") }

  context 'Resource AverageCPUTracking' do

    let(:resource) { template['Resources']['AverageCPUTracking'] }

    it 'is conditional' do
      expect(resource['Condition']).to eq('IsTargetTrackingScalingEnabled')
    end
  
    let(:properties) { resource['Properties'] }

    it 'has AutoScalingGroupName property that refs the AutoScaleGroup' do
      expect(properties['AutoScalingGroupName']).to eq({"Ref" => "AutoScaleGroup"})
    end

    it 'has PolicyType property with value of TargetTrackingScaling' do
      expect(properties['PolicyType']).to eq('TargetTrackingScaling')
    end

    it 'has TargetTrackingConfiguration property' do
      expect(properties['TargetTrackingConfiguration']).to eq({
        "PredefinedMetricSpecification" => {
          "PredefinedMetricType" => "ASGAverageCPUUtilization"
        },
        "TargetValue" => 60.0
      })
    end

  end

  context 'Resource RequestCountTracking' do

    let(:resource) { template['Resources']['RequestCountTracking'] }

    it 'is conditional' do
      expect(resource['Condition']).to eq('IsTargetTrackingScalingEnabled')
    end
  
    let(:properties) { resource['Properties'] }

    it 'has AutoScalingGroupName property that refs the AutoScaleGroup' do
      expect(properties['AutoScalingGroupName']).to eq({"Ref" => "AutoScaleGroup"})
    end

    it 'has PolicyType property with value of TargetTrackingScaling' do
      expect(properties['PolicyType']).to eq('TargetTrackingScaling')
    end

    it 'has TargetTrackingConfiguration property' do
      expect(properties['TargetTrackingConfiguration']).to eq({
        "PredefinedMetricSpecification" => {
          "PredefinedMetricType" => "ALBRequestCountPerTarget",
          "ResourceLabel" => {
            "Fn::Sub" => "${LoadBalancer}/${TargetGroup}"
          }
        },
        "TargetValue" => {
          "Ref" => "ALBRequestCountTargetValue"
        }
      })
    end

  end

end
