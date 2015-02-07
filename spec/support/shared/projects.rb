RSpec.shared_context 'projects' do
  let(:refspec) { double('RefSpec', matchSource: true) }
  let(:repository) { double('RemoteConfig', name: 'origin', getURIs: [double(URIish)], getFetchRefSpecs: [refspec]) }
  let(:build_chooser) { double('BuildChooser') }
  let(:scm1) { double(GitSCM, repositories: [repository], branches: [BranchSpec.new('origin/master')], buildChooser: build_chooser) }
  let(:project1) { double(AbstractProject, fullName: 'matching project', scm: scm1, isBuildable: true, isParameterized: false) }
  let(:scm2) { double(GitSCM, repositories: [repository], branches: [BranchSpec.new('origin/otherbranch')], buildChooser: build_chooser) }
  let(:project2) { double(AbstractProject, fullName: 'not matching project', scm: scm2, isBuildable: true, isParameterized: false) }
  let(:matching_project) { GitlabWebHook::Project.new(project1, multi_scm?: false) }
  let(:not_matching_project) { GitlabWebHook::Project.new(project2, multi_scm?: false) }

  before(:each) do
    allow(build_chooser).to receive(:java_kind_of?).with(InverseBuildChooser) { false }
    allow(scm1).to receive(:java_kind_of?).with(GitSCM) { true }
    allow(scm2).to receive(:java_kind_of?).with(GitSCM) { true }
  end
end
