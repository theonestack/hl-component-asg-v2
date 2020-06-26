require 'yaml'

describe 'compiled component' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/asg_scaling_simple.test.yaml")).to be_truthy
    end      
  end

  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/asg_scaling_simple/asg-v2.compiled.yaml") }

  context 'Resource ScaleUpAlarm' do

    let(:resource) { template['Resources']['ScaleUpAlarm'] }

    it 'is conditional' do
      expect(resource['Condition']).to eq('IsScalingEnabled')
    end
  
    let(:properties) { resource['Properties'] }

    it 'has property MetricName' do
      expect(properties['MetricName']).to eq('CPUReservation')
    end

    it 'has property Namespace' do
      expect(properties['Namespace']).to eq('AWS/EC2')
    end

    it 'has property Statistic' do
      expect(properties['Statistic']).to eq('Average')
    end

    it 'has property Period' do
      expect(properties['Period']).to eq('60')
    end

    it 'has property EvaluationPeriods' do
      expect(properties['EvaluationPeriods']).to eq('5')
    end

    it 'has property Threshold' do
      expect(properties['Threshold']).to eq('70')
    end

    it 'has property ComparisonOperator' do
      expect(properties['ComparisonOperator']).to eq('GreaterThanThreshold')
    end

    it 'has property Dimensions' do
      expect(properties['Dimensions']).to eq([{"Name" => "AutoScalingGroupName", "Value" => {"Ref" => "AutoScaleGroup"}}])
    end

    it 'has property AlarmActions' do
      expect(properties['AlarmActions']).to eq([{"Ref" => "ScaleUpPolicy"}])
  end

  end

  context 'Resource ScaleDownAlarm' do

    let(:resource) { template['Resources']['ScaleDownAlarm'] }

    it 'is conditional' do
      expect(resource['Condition']).to eq('IsScalingEnabled')
    end
  
    let(:properties) { resource['Properties'] }

    it 'has property MetricName' do
      expect(properties['MetricName']).to eq('CPUReservation')
    end

    it 'has property Namespace' do
      expect(properties['Namespace']).to eq('AWS/EC2')
    end

    it 'has property Statistic' do
      expect(properties['Statistic']).to eq('Average')
    end

    it 'has property Period' do
      expect(properties['Period']).to eq('300')
    end

    it 'has property EvaluationPeriods' do
      expect(properties['EvaluationPeriods']).to eq('10')
    end

    it 'has property Threshold' do
      expect(properties['Threshold']).to eq('40')
    end

    it 'has property ComparisonOperator' do
      expect(properties['ComparisonOperator']).to eq('LessThanThreshold')
    end

    it 'has property Dimensions' do
      expect(properties['Dimensions']).to eq([{"Name" => "AutoScalingGroupName", "Value" => {"Ref" => "AutoScaleGroup"}}])
    end

    it 'has property AlarmActions' do
      expect(properties['AlarmActions']).to eq([{"Ref" => "ScaleDownPolicy"}])
  end

  end

  context 'Resource ScaleUpPolicy' do

    let(:resource) { template['Resources']['ScaleUpPolicy'] }

    it 'is conditional' do
      expect(resource['Condition']).to eq('IsScalingEnabled')
    end
  
    let(:properties) { resource['Properties'] }

    it 'has property AdjustmentType' do
      expect(properties['AdjustmentType']).to eq('ChangeInCapacity')
    end

    it 'has property AutoScalingGroupName' do
      expect(properties['AutoScalingGroupName']).to eq({"Ref" => "AutoScaleGroup"})
    end

    it 'has property Cooldown' do
      expect(properties['Cooldown']).to eq('300')
    end

    it 'has property ScalingAdjustment' do
      expect(properties['ScalingAdjustment']).to eq(1)
    end

  end

  context 'Resource ScaleDownPolicy' do

    let(:resource) { template['Resources']['ScaleDownPolicy'] }

    it 'is conditional' do
      expect(resource['Condition']).to eq('IsScalingEnabled')
    end
  
    let(:properties) { resource['Properties'] }

    it 'has property AdjustmentType' do
      expect(properties['AdjustmentType']).to eq('ChangeInCapacity')
    end

    it 'has property AutoScalingGroupName' do
      expect(properties['AutoScalingGroupName']).to eq({"Ref" => "AutoScaleGroup"})
    end

    it 'has property Cooldown' do
      expect(properties['Cooldown']).to eq('300')
    end

    it 'has property ScalingAdjustment' do
      expect(properties['ScalingAdjustment']).to eq(-1)
    end

  end

end
