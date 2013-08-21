require 'spec_helper'

module GitlabWebHook
  describe GetBuildActions do
    let(:project) { double(:is_parametrized? => true) }
    let(:details) { double }

    context "when project not parametrized" do
      it "returns empty array" do
        expect(project).to receive(:is_parametrized?).and_return(false)
        expect(subject.with(project, details)).to eq([])
      end
    end

    context "when project parameters do not contain branch specifier" do
      it "returns empty array" do
        expect(project).to receive(:get_branch_name_parameter).and_return(nil)
        expect(subject.with(project, details)).to eq([])
      end
    end

    context "with project parameters" do
      let(:branch_parameter_value) { double("ParameterValue", :name => "BRANCH_NAME", :value => "master") }
      let(:branch_parameter) { double("Parameter", :name => "BRANCH_NAME", :getDefaultParameterValue => branch_parameter_value) }

      it "replaces branch parameter value with the one from details" do
        expect(project).to receive(:get_branch_name_parameter).and_return(branch_parameter)
        expect(project).to receive(:get_default_parameters).and_return([branch_parameter])
        expect(details).to receive(:branch).and_return("commit_branch")

        actions = subject.with(project, details)
        expect(actions.parameters.size).to eq(1)
        expect(actions.parameters[0].name).to eq("BRANCH_NAME")
        expect(actions.parameters[0].value).to eq("commit_branch")
      end

      let(:other_parameter_value) { double("ParameterValue", :name => "CAKE", :value => "muffin") }
      let(:other_parameter) { double("Parameter", :name => "CAKE", :getDefaultParameterValue => other_parameter_value) }

      it "keeps other parameters" do
        expect(project).to receive(:get_branch_name_parameter).and_return(branch_parameter)
        expect(project).to receive(:get_default_parameters).and_return([branch_parameter, other_parameter])
        expect(details).to receive(:branch).and_return("commit_branch")

        actions = subject.with(project, details)
        expect(actions.parameters.size).to eq(2)

        cake_parameter = actions.parameters.find { |parameter| parameter.name == "CAKE" }
        expect(cake_parameter).not_to be_nil
        expect(cake_parameter.value).to eq("muffin")
      end

      let(:nil_parameter) { double("Parameter", :name => "EMPTY_DEFAULT", :getDefaultParameterValue => nil) }

      it "removes nil values" do
        expect(project).to receive(:get_branch_name_parameter).and_return(branch_parameter)
        expect(project).to receive(:get_default_parameters).and_return([branch_parameter, other_parameter, nil_parameter])
        expect(details).to receive(:branch).and_return("commit_branch")

        actions = subject.with(project, details)
        expect(actions.parameters.size).to eq(2)

        nil_parameter = actions.parameters.find { |parameter| parameter.name == "EMPTY_DEFAULT" }
        expect(nil_parameter).to be_nil
      end
    end

    context "when validating" do
      it "requires project" do
        expect { subject.with(nil, details) }.to raise_exception(ArgumentError)
      end

      it "requires details" do
        expect { subject.with(project, nil) }.to raise_exception(ArgumentError)
      end
    end
  end
end
