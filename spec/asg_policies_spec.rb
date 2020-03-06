require 'yaml'

describe 'compiled component' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/asg_policies.test.yaml")).to be_truthy
    end      
  end

  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/asg_policies/asg-v2.compiled.yaml") }

  context 'Resource AutoScaleGroup Polices' do

    let(:asg) { template["Resources"]["AutoScaleGroup"] }

      it 'has Creation Policy' do
        expect(asg["CreationPolicy"]).to eq({
          "AutoScalingCreationPolicy" => {"MinSuccessfulInstancesPercent"=>50},
          "ResourceSignal" => {"Count"=>2, "Timeout"=>"PT5M"},
        })
      end

      it 'has Update Policy' do
        expect(asg["UpdatePolicy"]).to eq({
          "AutoScalingRollingUpdate" => {
            "MaxBatchSize"=>2, 
            "MinInstancesInService"=>1, 
            "PauseTime"=>"PT20M", 
            "SuspendProcesses"=>["HealthCheck", "ReplaceUnhealthy", "AZRebalance"],
            "WaitOnResourceSignals"=>"true"
          },
          "AutoScalingScheduledAction" => {"IgnoreUnmodifiedGroupSizeProperties"=>true}
        })
      end

  end

end