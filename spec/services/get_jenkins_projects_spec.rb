require 'spec_helper'
require 'spec/support/shared/settings'

module GitlabWebHook
  describe GetJenkinsProjects do
    include_context 'settings'

    before(:each) { allow(subject).to receive(:log_matched) {} }

    context 'when fetching projects by request details' do
      let(:details) { double(RequestDetails, full_branch_reference: 'refs/heads/master', branch: 'master', repository_uri: double(RepositoryUri)) }
      let(:matching_project) { double(Project) }
      let(:not_matching_project) { double(Project) }

      before(:each) { allow(subject).to receive(:all) { [not_matching_project, matching_project] } }

      it 'finds projects matching details' do
        expect(not_matching_project).to receive(:matches?).with(details.repository_uri, details.branch, details.full_branch_reference, false).and_return(false)
        expect(matching_project).to receive(:matches?).with(details.repository_uri, details.branch, details.full_branch_reference, false).and_return(true)

        projects = subject.matching(details)
        expect(projects.size).to eq(1)
        expect(projects[0]).to eq(matching_project)
      end

      it 'finds projects matching details exactly' do
        expect(not_matching_project).to receive(:matches?).with(details.repository_uri, details.branch, details.full_branch_reference, true).and_return(false)
        expect(matching_project).to receive(:matches?).with(details.repository_uri, details.branch, details.full_branch_reference, true).and_return(true)

        projects = subject.exactly_matching(details)
        expect(projects.size).to eq(1)
        expect(projects[0]).to eq(matching_project)
      end
    end

    context 'when fetching master project matching request details' do
      let(:details) { double(RequestDetails, full_branch_reference: 'refs/heads/master', branch: 'master', repository_uri: double(RepositoryUri, matches?: true)) }
      let(:refspec) { double('RefSpec', matchSource: true) }
      let(:repository) { double('RemoteConfig', name: 'origin', getURIs: [double(URIish)], getFetchRefSpecs: [refspec]) }
      let(:build_chooser) { double('BuildChooser') }
      let(:scm1) { double(GitSCM, repositories: [repository], branches: [BranchSpec.new('origin/master')], buildChooser: build_chooser) }
      let(:project1) { double(AbstractProject, fullName: 'matching project', scm: scm1, isBuildable: true, isParameterized: false) }
      let(:scm2) { double(GitSCM, repositories: [repository], branches: [BranchSpec.new('origin/otherbranch')], buildChooser: build_chooser) }
      let(:project2) { double(AbstractProject, fullName: 'not matching project', scm: scm2, isBuildable: true, isParameterized: false) }
      let(:matching_project) { Project.new(project1, multi_scm?: false) }
      let(:not_matching_project) { Project.new(project2, multi_scm?: false) }

      before(:each) do
        allow(build_chooser).to receive(:java_kind_of?).with(InverseBuildChooser) { false }
        allow(scm1).to receive(:java_kind_of?).with(GitSCM) { true }
        allow(scm2).to receive(:java_kind_of?).with(GitSCM) { true }
        allow(subject).to receive(:all) { [not_matching_project, matching_project] }
      end

      it 'finds project matching details and master branch' do
        expect(subject.master(details)).to eq(matching_project)
      end

      it 'finds first projects matching details and any non master branch' do
        expect(matching_project).to receive(:matches?).with(details.repository_uri, settings.master_branch, details.full_branch_reference, true).and_return(false)

        expect(subject.master(details)).to eq(not_matching_project)
      end
    end

    context 'when fetching projects by name' do
      before(:each) { allow(subject).to receive(:all) { [double(Project, name: '1st'), double(Project, name: '2nd')] } }

      it 'finds project by name' do
        projects = subject.named('2nd')
        expect(projects.size).to eq(1)
        expect(projects[0].name).to eq('2nd')
      end

      it 'does not find project by name' do
        projects = subject.named('3rd')
        expect(projects.size).to eq(0)
      end
    end

    context 'when fetching all projects from jenkins instance' do
      let(:scm) { double(GitSCM) }
      let(:jenkins_instance) { double(Java.jenkins.model.Jenkins, getAllItems: []) }

      before(:each) do
        allow(scm).to receive(:java_kind_of?).with(GitSCM) { true }
        allow(scm).to receive(:java_kind_of?).with(MultiSCM) { false }
        allow(Java.jenkins.model.Jenkins).to receive(:instance) { jenkins_instance }
      end

      it 'elevates privileges and restores them' do
        expect(subject).to receive(:elevate_priviledges).ordered
        expect(subject).to receive(:revert_priviledges).ordered
        subject.send(:all)
      end

      it 'returns custom projects' do
        allow(jenkins_instance).to receive(:getAllItems) {[
            double(Java.hudson.model.AbstractProject, scm: scm),
            double(Java.hudson.model.AbstractProject, scm: scm)
        ]}

        projects = subject.send(:all)
        expect(projects.size).to eq(2)
        projects.each { |project| expect(project).to be_kind_of(Project) }
      end
    end
  end
end
