require 'spec_helper'

include Java

java_import Java.hudson.model.ParametersAction

module GitlabWebHook
  describe GetBuildActions do
    let(:project) { double(Project, parametrized?: true) }
    let(:details) { double(RequestDetails) }

    context 'when project not parametrized' do
      it 'returns empty array' do
        project.stub(:parametrized?).and_return(false)
        expect(subject.with(project, details)).to eq([])
      end
    end

    context 'when building actions' do
      let(:parameters_values) { [] }
      before(:each) { GetParametersValues.any_instance.should_receive(:with).with(project, details).and_return(parameters_values) }

      it 'delegates parameter values build' do
        subject.with(project, details)
      end

      it 'returns parameters action' do
        expect(subject.with(project, details).java_kind_of?(ParametersAction)).to be_truthy
      end

      it 'parameters action contain parameters values' do
        expect(subject.with(project, details).getParameters()).to eq(parameters_values)
      end
    end

    context 'when validating' do
      it 'requires project' do
        expect { subject.with(nil, details) }.to raise_exception(ArgumentError)
      end

      it 'requires details' do
        expect { subject.with(project, nil) }.to raise_exception(ArgumentError)
      end
    end
  end
end
