RSpec.shared_context 'projects' do
  let(:repo_url) { 'http://example.com/diaspora/diaspora.git' }
                  # 'http://example.com/diaspora/diaspora',
  #let(:repo_url) { 'git@example.com:diaspora/diaspora.git' }
     #             'git@example.com:diaspora/diaspora.git',
  let(:refspec) { double('RefSpec', matchSource: true) }
  let(:repository) { double('RemoteConfig', name: 'origin', getURIs: [URIish.new(repo_url)], getFetchRefSpecs: [refspec]) }
  let(:build_chooser) { double('BuildChooser') }
  let(:scm1) { double(GitSCM, repositories: [repository], branches: [BranchSpec.new('origin/master')], buildChooser: build_chooser, extensions: double('ExtensionsList', get: nil)) }
  let(:java_project1) { double(AbstractProject, fullName: 'matching project', scm: scm1, isBuildable: true, isParameterized: false) }
  let(:scm2) { double(GitSCM, repositories: [repository], branches: [BranchSpec.new('origin/otherbranch')], buildChooser: build_chooser, extensions: double('ExtensionsList', get: nil)) }
  let(:java_project2) { double(AbstractProject, fullName: 'not matching project', scm: scm2, isBuildable: true, isParameterized: false) }
  let(:matching_project) { GitlabWebHook::Project.new(java_project1, multi_scm?: false) }
  let(:not_matching_project) { GitlabWebHook::Project.new(java_project2, multi_scm?: false) }

  let(:repo_url3) { 'git@example.com:discourse/discourse.git' }
  let(:repository3) { double('RemoteConfig', name: 'origin', getURIs: [URIish.new(repo_url3)], getFetchRefSpecs: [refspec]) }
  let(:scm3) { double(GitSCM, repositories: [repository3], branches: [BranchSpec.new('origin/master')], buildChooser: build_chooser, extensions: double('ExtensionsList', get: nil)) }
  let(:java_project3) { double(AbstractProject, fullName: 'autocreate matching project', scm: scm3, isBuildable: true, isParameterized: false) }
  let(:autocreate_match_project) { GitlabWebHook::Project.new(java_project3, multi_scm?: false) }

  let(:all_projects) { [ not_matching_project , matching_project , autocreate_match_project ] }

  before(:each) do
    allow(build_chooser).to receive(:java_kind_of?).with(InverseBuildChooser) { false }
    allow(scm1).to receive(:java_kind_of?).with(GitSCM) { true }
    allow(scm2).to receive(:java_kind_of?).with(GitSCM) { true }
    allow(scm3).to receive(:java_kind_of?).with(GitSCM) { true }
    allow(scm1).to receive(:java_kind_of?).with(MultiSCM) { false }
    allow(scm2).to receive(:java_kind_of?).with(MultiSCM) { false }
    allow(scm3).to receive(:java_kind_of?).with(MultiSCM) { false }
  end
end
