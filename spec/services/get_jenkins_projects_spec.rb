require 'spec_helper'

require 'models/root_action_descriptor'

module GitlabWebHook
  describe GetJenkinsProjects do
    context 'when fetching projects by request details' do
      let(:details) { double(RequestDetails, branch: 'master', repository_uri: double(RepositoryUri)) }
      let(:matching_project) { double(Project) }
      let(:not_matching_project) { double(Project) }

      before(:each) { allow(subject).to receive(:matching_uri) { [not_matching_project, matching_project] } }

      it 'finds projects matching details' do
        expect(not_matching_project).to receive(:matches?).with(details).and_return(false)
        expect(matching_project).to receive(:matches?).with(details).and_return(true)

        projects = subject.matching_uri.select do |project|
          project.matches?(details)
        end

        expect(projects.size).to eq(1)
        expect(projects[0]).to eq(matching_project)
      end

      it 'finds projects matching details exactly' do
        expect(not_matching_project).to receive(:matches?).with(details, details.branch, true).and_return(false)
        expect(matching_project).to receive(:matches?).with(details, details.branch, true).and_return(true)

        projects = subject.matching_uri.select do |project|
          project.matches?(details, details.branch, true)
        end
        expect(projects.size).to eq(1)
        expect(projects[0]).to eq(matching_project)
      end
    end

    context 'when fetching master project matching request details' do
      let(:details) { double(RequestDetails, branch: 'master', repository_uri: double(RepositoryUri)) }
      let(:matching_project) { double(Project) }
      let(:not_matching_project) { double(Project) }
      let(:jenkins_instance) { double(Java.jenkins.model.Jenkins) }

      before(:each) do
        allow(Java.jenkins.model.Jenkins).to receive(:instance) { jenkins_instance }
        allow(jenkins_instance).to receive(:descriptor) { GitlabWebHookRootActionDescriptor.new }
        expect(subject).to receive(:all) { [not_matching_project, matching_project] }
      end

      it 'finds project matching details and master branch' do
        expect(not_matching_project).to receive(:matches?).with(details, GitlabWebHookRootActionDescriptor.new.any_branch_pattern).and_return(true)
        expect(not_matching_project).to receive(:matches?).with(details, GitlabWebHookRootActionDescriptor.new.master_branch, true).and_return(false)
        expect(matching_project).to receive(:matches?).with(details, GitlabWebHookRootActionDescriptor.new.any_branch_pattern).and_return(true)
        expect(matching_project).to receive(:matches?).with(details, GitlabWebHookRootActionDescriptor.new.master_branch, true).and_return(true)

        expect(subject.master(details)).to eq(matching_project)
      end

      it 'finds first projects matching details and any non master branch' do
        expect(not_matching_project).to receive(:matches?).with(details, GitlabWebHookRootActionDescriptor.new.any_branch_pattern).and_return(true)
        expect(not_matching_project).to receive(:matches?).with(details, GitlabWebHookRootActionDescriptor.new.master_branch, true).and_return(false)
        expect(matching_project).to receive(:matches?).with(details, GitlabWebHookRootActionDescriptor.new.any_branch_pattern).and_return(true)
        expect(matching_project).to receive(:matches?).with(details, GitlabWebHookRootActionDescriptor.new.master_branch, true).and_return(false)

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
      let(:jenkins_instance) { double(Java.jenkins.model.Jenkins, getAllItems: []) }

      before(:each) { allow(Java.jenkins.model.Jenkins).to receive(:instance) { jenkins_instance } }

      it 'elevates privileges and restores them' do
        expect(subject).to receive(:elevate_priviledges).ordered
        expect(subject).to receive(:revert_priviledges).ordered
        subject.send(:all)
      end

      it 'returns custom projects' do
        allow(jenkins_instance).to receive(:getAllItems) { [double(Java.hudson.model.AbstractProject), double(Java.hudson.model.AbstractProject)] }

        projects = subject.send(:all)
        expect(projects.size).to eq(2)
        projects.each { |project| expect(project).to be_kind_of(Project) }
      end
    end
  end
end
