require 'spec_helper'

module GitlabWebHook
  describe Project do
    let(:jenkins_project) { double(AbstractProject, fullName: 'diaspora') }
    let(:logger) { double }
    let(:subject) { Project.new(jenkins_project, logger) }

    context 'when initializing' do
      it 'requires jenkins project' do
        expect { Project.new(nil) }.to raise_exception(ArgumentError)
      end
    end

    context 'when exposing jenkins project interface' do
      [:scm, :schedulePolling, :scheduleBuild2, :fullName, :isParameterized, :isBuildable, :getQuietPeriod, :getProperty, :delete, :description].each do |message|
        it "delegates #{message}" do
          expect(jenkins_project).to receive(message)
          subject.send(message)
        end
      end

      {parametrized?: :isParameterized, buildable?: :isBuildable, name: :fullName, to_s: :fullName}.each do |aliased, original|
        it "has nicer alias for #{original}" do
          expect(jenkins_project).to receive(original)
          subject.send(aliased)
        end
      end
    end

    context 'when determining if matches repository url and branch' do
      let(:scm) { double(GitSCM) }
      let(:repository) { double('RemoteConfig', name: 'origin', getURIs: [double(URIish)]) }
      let(:details_uri) { double(RepositoryUri) }
      let(:branch) { double('BranchSpec', matches: true) }
      let(:build_chooser) { double('BuildChooser') }

      before (:each) do
        allow(subject).to receive(:buildable?) { true }
        allow(subject).to receive(:parametrized?) { false }

        allow(build_chooser).to receive(:java_kind_of?).with(InverseBuildChooser) { false }

        allow(scm).to receive(:java_kind_of?).with(GitSCM) { true }
        allow(scm).to receive(:repositories) { [repository] }
        allow(scm).to receive(:branches) { [branch] }
        allow(scm).to receive(:buildChooser) { build_chooser }

        allow(details_uri).to receive(:matches?) { true }

        allow(jenkins_project).to receive(:scm) { scm }
      end

      context 'it is not matching' do
        it 'when it is not buildable' do
          allow(subject).to receive(:buildable?) { false }
          expect(subject.matches?(anything, anything)).not_to be
        end

        it 'when it is not git' do
          allow(scm).to receive(:java_kind_of?).with(GitSCM) { false }
          expect(subject.matches?(anything, anything)).not_to be
        end

        it 'when repo uris do not match' do
          allow(details_uri).to receive(:matches?) { false }
          expect(subject.matches?(details_uri, anything)).not_to be
        end

        it 'when branches do not match' do
          allow(branch).to receive(:matches) { false }
          expect(logger).to receive(:info)
          expect(subject.matches?(details_uri, anything)).not_to be
        end
      end

      context 'it matches' do
        before(:each) do
          expect(logger).to receive(:info)
        end

        it 'when is buildable, is git, repo uris match and branches match' do
          expect(subject.matches?(details_uri, anything)).to be
        end
      end

      context 'when parametrized' do
        let(:branch_name_parameter) { double(ParametersDefinitionProperty, name: 'BRANCH_NAME') }

        before(:each) do
          allow(branch_name_parameter).to receive(:java_kind_of?).with(StringParameterDefinition) { true }

          other_parameter = double(ParametersDefinitionProperty, name: 'OTHER_PARAMETER')
          allow(other_parameter).to receive(:java_kind_of?).with(StringParameterDefinition) { true }

          allow(branch).to receive(:matches) { false }
          allow(branch).to receive(:name) { 'origin/$BRANCH_NAME' }

          allow(subject).to receive(:parametrized?) { true }
          allow(subject).to receive(:get_default_parameters) { [branch_name_parameter, other_parameter] }
        end

        it 'does not match when branch parameter not found' do
          allow(branch_name_parameter).to receive(:name) { 'NOT_BRANCH_PARAMETER' }
          expect(logger).to receive(:info)
          expect(subject.matches?(details_uri, anything)).not_to be
        end

        it 'raises exception when branch parameter is not of supported type' do
          allow(branch_name_parameter).to receive(:java_kind_of?).with(StringParameterDefinition) { false }
          expect { subject.matches?(details_uri, anything) }.to raise_exception(ConfigurationException)
        end

        it 'matches when branch parameter found and is of supported type' do
          expect(logger).to receive(:info)
          expect(subject.matches?(details_uri, anything)).to be
        end

        it 'supports parameter usage without $' do
          allow(branch).to receive(:name) { 'origin/BRANCH_NAME' }
          expect(logger).to receive(:info)
          expect(subject.matches?(details_uri, anything)).to be
        end
      end

      context 'when matching exactly' do
        it 'does not match when branches are not equal' do
          allow(branch).to receive(:name) { 'origin/**' }
          expect(logger).to receive(:info)
          expect(subject.matches?(details_uri, 'origin/master', true)).not_to be
        end

        it 'matches when branches are equal' do
          allow(branch).to receive(:name) { 'origin/master' }
          expect(logger).to receive(:info)
          expect(subject.matches?(details_uri, 'origin/master', true)).not_to be
        end
      end

      context 'with inverse match strategy' do
        before(:each) do
          allow(build_chooser).to receive(:java_kind_of?).with(InverseBuildChooser) { true }
          expect(logger).to receive(:info)
        end

        it 'does not match when regular strategy would match' do
          expect(subject.matches?(details_uri, anything)).not_to be
        end

        it 'matches when regular strategy would not match' do
          allow(branch).to receive(:matches) { false }
          expect(subject.matches?(details_uri, anything)).to be
        end
      end
    end
  end
end
