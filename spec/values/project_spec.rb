require 'spec_helper'

module GitlabWebHook
  describe Project do
    let(:scm) { double(GitSCM) }
    let(:jenkins_project) { double(AbstractProject, fullName: 'diaspora') }
    let(:logger) { double }
    let(:subject) { Project.new(jenkins_project, logger) }

    context 'when initializing' do
      it 'requires jenkins project' do
        expect { Project.new(nil) }.to raise_exception(ArgumentError)
      end
    end

    context 'when exposing jenkins project interface' do
      before(:each) do
        allow(scm).to receive(:java_kind_of?).with(GitSCM) { true }
        allow(scm).to receive(:java_kind_of?).with(MultiSCM) { false }
        allow(jenkins_project).to receive(:scm) { scm }
      end

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
      let(:repository) { double('RemoteConfig', name: 'origin', getURIs: [double(URIish)]) }
      let(:refspec) { double('RefSpec') }
      let(:details_uri) { double(RepositoryUri) }
      let(:details) { double(RequestDetails, branch: 'master', repository_uri: details_uri, full_branch_reference: 'refs/heads/master', tagname: nil) }
      #let(:branch) { BranchSpec.new('origin/master') }
      let(:build_chooser) { double('BuildChooser') }

      before(:each) do
        allow(scm).to receive(:java_kind_of?).with(GitSCM) { true }
        allow(scm).to receive(:java_kind_of?).with(MultiSCM) { false }
        allow(jenkins_project).to receive(:scm) { scm }

        allow(subject).to receive(:buildable?) { true }
        allow(subject).to receive(:parametrized?) { false }
        allow(subject).to receive(:pre_build_merge) { nil }

        allow(build_chooser).to receive(:java_kind_of?).with(InverseBuildChooser) { false }

        allow(scm).to receive(:repositories) { [repository] }
        allow(scm).to receive(:branches) { [BranchSpec.new('origin/master')] }
        allow(scm).to receive(:buildChooser) { build_chooser }

        allow(details_uri).to receive(:matches?) { true }

        allow(repository).to receive(:getFetchRefSpecs) { [refspec] }
        allow(refspec).to receive(:matchSource).with(anything) { true }
      end

      context 'it is not matching' do
        it 'when it is not buildable' do
          allow(subject).to receive(:buildable?) { false }
          expect(subject.matches?(details)).not_to be
        end

        it 'when it is not git and is not multiple smsc' do
          allow(scm).to receive(:java_kind_of?).with(GitSCM) { false }
          allow(scm).to receive(:java_kind_of?).with(MultiSCM) { false }
          expect(subject.matches?(details)).not_to be
        end

        it 'when repo uris do not match' do
          allow(details_uri).to receive(:matches?) { false }
          expect(subject.matches?(details)).not_to be
        end

        it 'when branches do not match' do
          allow(scm).to receive(:branches) { [BranchSpec.new('origin/nonmatchingbranch')] }
          expect(subject.matches?(details)).not_to be
        end

        it 'when refspec does not match' do
          allow(refspec).to receive(:matchSource).with(anything) { false }
          expect(subject.matches?(details)).not_to be
        end

      end

      context 'it matches' do
        it 'when is buildable, is git, repo uris match and branches match' do
          expect(subject.matches?(details)).to be
        end

        it 'when is buildable, is multiple smsc, repo uris match and branches match' do
          allow(scm).to receive(:java_kind_of?).with(GitSCM) { false }
          allow(scm).to receive(:java_kind_of?).with(MultiSCM) { true }
          expect(subject.matches?(details)).to be
        end
      end

      context 'when is merge project' do
        before(:each) do
          allow(scm).to receive(:branches) { [BranchSpec.new('origin/nonmatchingbranch')] }
        end

        it 'and merged branch matchs' do
          expect(logger).to receive(:info)
          expect(subject).to receive(:merge_to?) { true }
          expect(subject.matches?(details)).to be
        end

        it 'and merged branch matchs' do
          expect(subject).to receive(:merge_to?) { false }
          expect(subject.matches?(details)).not_to be
        end
      end

      context 'when parametrized' do
        let(:branch_name_parameter) { double(ParametersDefinitionProperty, name: 'BRANCH_NAME') }
        let(:tagname_parameter) { double(ParametersDefinitionProperty, name: 'TAGNAME') }

        before(:each) do
          allow(branch_name_parameter).to receive(:java_kind_of?).with(StringParameterDefinition) { true }
          allow(tagname_parameter).to receive(:java_kind_of?).with(StringParameterDefinition) { true }

          other_parameter = double(ParametersDefinitionProperty, name: 'OTHER_PARAMETER')
          allow(other_parameter).to receive(:java_kind_of?).with(StringParameterDefinition) { true }

          allow(scm).to receive(:branches) { [BranchSpec.new('origin/$BRANCH_NAME')] }

          allow(subject).to receive(:parametrized?) { true }
          allow(subject).to receive(:get_default_parameters) { [branch_name_parameter, other_parameter] }
        end

        it 'does not match when branch parameter not found' do
          allow(branch_name_parameter).to receive(:name) { 'NOT_BRANCH_PARAMETER' }
          expect(subject.matches?(details)).not_to be
        end

        it 'does not match when branch parameter is not of supported type' do
          Project::BRANCH_NAME_PARAMETER_ACCEPTED_TYPES.each { |type| allow(branch_name_parameter).to receive(:java_kind_of?).with(type) { false } }
          expect(logger).to receive(:warning)
          expect(subject.matches?(details)).not_to be
        end

        it 'matches when branch parameter found and is of supported type' do
          expect(subject.matches?(details)).to be
        end

        it 'supports parameter usage without $' do
          allow(scm).to receive(:branches) { [BranchSpec.new('origin/BRANCH_NAME')] }
          expect(subject.matches?(details)).to be
        end

        it 'does not match when refspec do not match' do
          allow(refspec).to receive(:matchSource).with(anything) { false }
          expect(subject.matches?(details)).not_to be
        end

        it 'handles TAGNAME' do
          allow(scm).to receive(:branches) { [BranchSpec.new('refs/tags/${TAGNAME}')] }
          allow(subject).to receive(:get_default_parameters) { [branch_name_parameter, tagname_parameter] }
          expect(subject.matches?(details)).not_to be
        end
      end

      context 'when matching exactly' do
        it 'does not match when branches are not equal' do
          allow(scm).to receive(:branches) { [BranchSpec.new('origin/**')] }
          expect(subject.matches?(details, 'origin/master', true)).not_to be
        end

        it 'matches when branches are equal' do
          allow(scm).to receive(:branches) { [BranchSpec.new('origin/master')] }
          expect(subject.matches?(details, 'origin/master', true)).not_to be
        end
      end

      context 'with inverse match strategy' do
        before(:each) { allow(build_chooser).to receive(:java_kind_of?).with(InverseBuildChooser) { true } }

        it 'does not match when regular strategy would match' do
          expect(subject.matches?(details)).not_to be
        end

        it 'matches when regular strategy would not match' do
          allow(scm).to receive(:branches) { [BranchSpec.new('origin/nonmatchingbranch')] }
          expect(subject.matches?(details)).to be
        end
      end
    end

    context 'with mutiple smc' do
      let(:not_git_scm) { double(Object) }
      let(:regular_git_scm) { double(GitSCM) }
      let(:inverse_git_scm) { double(GitSCM) }

      let(:repository) { double('RemoteConfig', name: 'origin', getURIs: [double(URIish)]) }
      let(:refspec) { double('RefSpec') }
      let(:details_uri) { double(RepositoryUri) }
      let(:details) { double(RequestDetails, branch: 'master', repository_uri: details_uri, full_branch_reference: nil) }
      let(:matching_branch) { double('BranchSpec', matches: true, name: 'origin') }
      let(:non_matching_branch) { double('BranchSpec', matches: false, name: 'origin') }
      let(:default_build_chooser) { double('BuildChooser') }
      let(:inverse_build_chooser) { double('BuildChooser') }

      before(:each) do
        allow(not_git_scm).to receive(:java_kind_of?).with(GitSCM) { false }

        allow(regular_git_scm).to receive(:java_kind_of?).with(GitSCM) { true }
        allow(regular_git_scm).to receive(:repositories) { [repository] }
        allow(regular_git_scm).to receive(:buildChooser) { default_build_chooser }
        allow(regular_git_scm).to receive(:extensions) { double('ExtensionsList', get: nil) }

        allow(inverse_git_scm).to receive(:java_kind_of?).with(GitSCM) { true }
        allow(inverse_git_scm).to receive(:repositories) { [repository] }
        allow(inverse_git_scm).to receive(:buildChooser) { inverse_build_chooser }
        allow(inverse_git_scm).to receive(:extensions) { double('ExtensionsList', get: nil) }

        allow(scm).to receive(:java_kind_of?).with(GitSCM) { false }
        allow(scm).to receive(:java_kind_of?).with(MultiSCM) { true }
        allow(scm).to receive(:getConfiguredSCMs) { [regular_git_scm, not_git_scm, inverse_git_scm] }
        allow(scm).to receive(:extensions) { double('ExtensionsList', get: nil) }

        allow(jenkins_project).to receive(:scm) { scm }

        allow(subject).to receive(:buildable?) { true }
        allow(subject).to receive(:parametrized?) { false }

        allow(default_build_chooser).to receive(:java_kind_of?).with(InverseBuildChooser) { false }
        allow(inverse_build_chooser).to receive(:java_kind_of?).with(InverseBuildChooser) { true }

        allow(details_uri).to receive(:matches?) { true }

        allow(repository).to receive(:getFetchRefSpecs) { [refspec] }
        allow(refspec).to receive(:matchSource).with(anything) { true }
      end

      context 'when no scm applies' do
        before(:each) do
          allow(regular_git_scm).to receive(:branches) { [non_matching_branch] }
          allow(inverse_git_scm).to receive(:branches) { [matching_branch] }
        end

        it 'does not match' do
          expect(subject.matches?(details)).not_to be
        end
      end

      context 'when regular scm applies' do
        before(:each) do
          allow(regular_git_scm).to receive(:branches) { [matching_branch] }
          allow(inverse_git_scm).to receive(:branches) { [matching_branch] }
        end

        it 'matches' do
          expect(subject.matches?(details)).to be
        end
      end

      context 'when inverse scm applies' do
        before(:each) do
          allow(regular_git_scm).to receive(:branches) { [non_matching_branch] }
          allow(inverse_git_scm).to receive(:branches) { [non_matching_branch] }
        end

        it 'matches' do
          expect(subject.matches?(details)).to be
        end
      end
    end

    context "#matches?(branch='master')" do
      include_context 'details'
      let(:scm) { GitSCM.new( 'git@example.com:diaspora/diaspora.git' ) }

      before (:each) do
        allow(scm).to receive(:branches) { [branch] }
        allow(jenkins_project).to receive(:scm) { scm }
        allow(subject).to receive(:buildable?) { true }
        allow(subject).to receive(:parametrized?) { false }
      end

      context "branchspec is 'master'" do
        let(:branch) { BranchSpec.new('master') }
        it "matches" do
          expect( subject.matches?(details) ).to be(true)
        end
      end

      context "branchspec is 'origin/master'" do
        let(:branch) { BranchSpec.new('origin/master') }
        it "matches" do
          expect( subject.matches?(details) ).to be(true)
        end
      end

      context "branchspec is 'other/master'" do
        let(:branch) { BranchSpec.new('other/master') }
        it "don't match" do
          expect( subject.matches?(details) ).to be(false)
        end
      end

      context "branchspec is '*/master'" do
        let(:branch) { BranchSpec.new('*/master') }
        it "match" do
          expect( subject.matches?(details) ).to be(true)
        end
      end

      context "branchspec is 'origin/otherbranch'" do
        let(:branch) { BranchSpec.new('origin/otherbranch') }
        it "don't match" do
          expect( subject.matches?(details) ).to be(false)
        end
      end

    end

    context "#matches?(branch='master', exactly=true)" do
      include_context 'details'
      let(:scm) { GitSCM.new( 'git@example.com:diaspora/diaspora.git' ) }

      before (:each) do
        allow(scm).to receive(:branches) { [branch] }
        allow(jenkins_project).to receive(:scm) { scm }
        allow(subject).to receive(:buildable?) { true }
        allow(subject).to receive(:parametrized?) { false }
      end

      context "branchspec is 'master'" do
        let(:branch) { BranchSpec.new('master') }
        it "matches" do
          expect( subject.matches?(details, false, true) ).to be(true)
        end
      end

      context "branchspec is 'origin/master'" do
        let(:branch) { BranchSpec.new('origin/master') }
        it "matches" do
          expect( subject.matches?(details, false, true) ).to be(true)
        end
      end

      context "when branchspec is 'other/master'" do
        let(:branch) { BranchSpec.new('other/master') }
        it "don't match" do
          expect( subject.matches?(details, false, true) ).to be(false)
        end
      end

      context "branchspec is '*/master'" do
        let(:branch) { BranchSpec.new('*/master') }
        it "matches" do
          expect( subject.matches?(details, false, true) ).to be(true)
        end
      end

      context "when branchspec is 'origin/otherbranch'" do
        let(:branch) { BranchSpec.new('origin/otherbranch') }
        it "don't match" do
          expect( subject.matches?(details, false, true) ).to be(false)
        end
      end

    end

    context 'when tag was pushed' do
      let(:scm) { double(GitSCM,
                            repositories: [ double('RemoteConfig',
                                                         name: 'origin',
                                                         getURIs: [double(URIish)],
                                                         getFetchRefSpecs: [refspec]
	                                                 )],
                            branches: [branch],
                            extensions: double('ExtensionsList', get: nil),
                            buildChooser: build_chooser
	                    )}
      let(:refspec) { double('RefSpec') }
      let(:build_chooser) { double('BuildChooser') }
      let(:details_uri) { double(RepositoryUri, matches?: true) }
      let(:details) { double(RequestDetails, repository_uri: details_uri, full_branch_reference: 'refs/tags/v1.0.0', branch: 'tags/v1.0.0', tagname: 'v1.0.0') }

      before (:each) do
        allow(jenkins_project).to receive(:scm) { scm }
        allow(scm).to receive(:java_kind_of?).with(GitSCM) { true }
        allow(scm).to receive(:java_kind_of?).with(MultiSCM) { false }

        allow(refspec).to receive(:matchSource).with(anything) { true }
        allow(build_chooser).to receive(:java_kind_of?).with(InverseBuildChooser) { false }

        allow(subject).to receive(:buildable?) { true }
      end

      let(:branch_name_parameter) { double(ParametersDefinitionProperty, name: 'BRANCH_NAME') }
      let(:tagname_parameter) { double(ParametersDefinitionProperty, name: 'TAGNAME') }

      before (:each) do
        allow(subject).to receive(:parametrized?) { true }
        allow(subject).to receive(:get_default_parameters) { [branch_name_parameter, tagname_parameter] }
        allow(branch_name_parameter).to receive(:java_kind_of?).with(StringParameterDefinition) { true }
        allow(tagname_parameter).to receive(:java_kind_of?).with(StringParameterDefinition) { true }
      end

      context 'with fixed BranchSpec' do
        let(:branch) { BranchSpec.new('origin/master') }
        it 'skips building' do
          expect(subject.matches?(details)).not_to be
        end
      end

      context 'with other parameters on BranchSpec' do
        let(:branch) { BranchSpec.new('origin/${BRANCH_NAME}') }
        it 'skips building' do
          expect(subject.matches?(details)).not_to be
        end
      end

      context 'with tag ready BranchSpec' do
        let(:branch) { BranchSpec.new('refs/tags/${TAGNAME}') }
        it 'builds project' do
          expect(subject.matches?(details)).to be
        end
      end
    end

    context 'when looking for "Merge before build" extension' do
      before(:each) do
        allow(scm).to receive(:java_kind_of?).with(GitSCM) { true }
        allow(scm).to receive(:java_kind_of?).with(MultiSCM) { false }
        allow(jenkins_project).to receive(:scm) { scm }
      end

      context 'method pre_build_merge? returns' do
        it 'false when extension not present' do
          expect(subject).to receive(:pre_build_merge) { nil }
          expect(subject.pre_build_merge?).to be(false)
        end
	it 'true when extension is present' do
          expect(subject).to receive(:pre_build_merge) { double(PreBuildMerge) }
          expect(subject.pre_build_merge?).to be(true)
        end
      end
      context 'method merge_to? returns' do
        let(:user_merge_options) { UserMergeOptions.new('origin', 'dest_branch', 'default') }
        let(:pre_build_merge) { PreBuildMerge.new(user_merge_options) }
        before (:each) do
          expect(subject).to receive(:pre_build_merge).twice { pre_build_merge }
        end
        it 'false when branch do not match' do
          expect(subject.merge_to?('other_branch')).to be(false)
        end
	it 'true when match matches' do
          expect(subject.merge_to?('dest_branch')).to be(true)
        end
      end
    end

  end
end
