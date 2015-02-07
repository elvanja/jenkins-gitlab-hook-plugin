require 'spec_helper'

include Java

java_import Java.hudson.model.StringParameterDefinition
java_import Java.hudson.model.BooleanParameterValue

module GitlabWebHook
  describe GetParametersValues do
    include_context 'details'

    def build_parameter(name, default = nil)
      double(name: name, getDefaultParameterValue: default ? StringParameterValue.new(name, default) : nil).tap do |parameter|
        allow(parameter).to receive(:java_kind_of?).with(StringParameterDefinition) { true }
      end
    end

    let(:project) { double(Project, get_branch_name_parameter: nil) }

    context 'with parameters present in payload data' do
      it 'recognizes root keys' do
        allow(project).to receive(:get_default_parameters) { [build_parameter('before')] }
        expect(subject.with(project, details)[0].value).to eq('95790bf891e76fee5e1747ab589903a6a1f80f22')
      end

      it 'recognizes nested keys' do
        allow(project).to receive(:get_default_parameters) { [build_parameter('repository.url')] }
        expect(subject.with(project, details)[0].value).to eq('git@example.com:diaspora.git')
      end

      it 'recognizes nested array elements' do
        allow(project).to receive(:get_default_parameters) { [build_parameter('commits.1.id')] }
        expect(subject.with(project, details)[0].value).to eq('da1560886d4f094c3e6c9ef40349f7d38b5d27d7')
      end

      it 'recognizes deep nested elements' do
        allow(project).to receive(:get_default_parameters) { [build_parameter('commits.0.author.email')] }
        expect(subject.with(project, details)[0].value).to eq('jsmith@example.com')
      end
    end

    context 'with branch parameter' do
      it 'replaces it with data from details' do
        branch_parameter = build_parameter('commit_branch_parameter', 'default_branch')
        allow(project).to receive(:get_branch_name_parameter) { branch_parameter }
        allow(project).to receive(:get_default_parameters) { [branch_parameter] }
        allow(details).to receive(:branch) { 'commit_branch' }
        expect(subject.with(project, details)[0].value).to eq('commit_branch')
      end
    end

    context 'with parameters not in payload' do
      before(:each) { allow(project).to receive(:get_default_parameters) { [build_parameter('not_in_payload', 'default value')] } }

      it 'keeps them' do
        expect(subject.with(project, details)[0].name).to eq('not_in_payload')
      end

      it 'applies default value' do
        expect(subject.with(project, details)[0].value).to eq('default value')
      end
    end

    context 'with empty values' do
      it 'removes them' do
        allow(project).to receive(:get_default_parameters) { [build_parameter('not_in_payload')] }
        expect(subject.with(project, details).size).to eq(0)
      end
    end

    context 'with parameters in general' do
      it 'is case insensitive' do
        allow(project).to receive(:get_branch_name_parameter) { build_parameter('commit_branch_parameter') }
        allow(project).to receive(:get_default_parameters) { [
          build_parameter('not_IN_payload', 'default value'),
          build_parameter('BEFORE'),
          build_parameter('commit_BRANCH_parameter')
        ] }
        allow(details).to receive(:branch) { 'commit_branch' }
        expect(subject.with(project, details)[0].value).to eq('default value')
        expect(subject.with(project, details)[1].value).to eq('95790bf891e76fee5e1747ab589903a6a1f80f22')
        expect(subject.with(project, details)[2].value).to eq('commit_branch')
      end

      it 'leaves non string parameters as is' do
        boolean_parameter = double(name: 'boolean', getDefaultParameterValue: BooleanParameterValue.new('boolean', true)).tap do |parameter|
          allow(parameter).to receive(:java_kind_of?).with(StringParameterDefinition) { false }
        end
        allow(project).to receive(:get_default_parameters) { [boolean_parameter] }
        expect(subject.with(project, details)[0].value).to eq(true)
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
