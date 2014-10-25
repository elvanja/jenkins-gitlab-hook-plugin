require 'spec_helper'

require 'models/root_action_descriptor'

module GitlabWebHook
  describe ProcessCommit do
    let(:details) { double(RequestDetails, repository_uri: 'git@gitlab.com/group/discourse', branch: 'master') }
    let(:action) { double(Proc) }
    let(:project) { double(Project) }
    let(:get_jenkins_projects) { double(GetJenkinsProjects) }
    let(:create_project_for_branch) { double(CreateProjectForBranch) }
    let(:subject) { ProcessCommit.new(get_jenkins_projects, create_project_for_branch) }
    let(:jenkins_instance) { double(Java.jenkins.model.Jenkins) }

    context 'with related projects' do
      before(:each) { allow(subject).to receive(:get_projects_to_process) { [project, project] } }
      it 'calls action with found project and related details' do
        expect(action).to receive(:call).with(project, details).twice
        subject.with(details, action)
      end

      it 'returns messages collected by calls to action' do
        expect(action).to receive(:call).with(project, details).twice.and_return('executed')
        expect(subject.with(details, action)).to eq(%w(executed executed))
      end
    end

    context 'when automatic project creation is offline' do

      before(:each) do
        allow(Java.jenkins.model.Jenkins).to receive(:instance) { jenkins_instance }
        allow(jenkins_instance).to receive(:descriptor) { GitlabWebHookRootActionDescriptor.new }
        expect(create_project_for_branch).not_to receive(:with)
      end

      it 'searches matching projects' do
        allow(jenkins_instance).to receive(:descriptor) { GitlabWebHookRootActionDescriptor.new }
        allow(project).to receive(:matches?) { true }
        expect(get_jenkins_projects).to receive(:matching_uri).with(details).and_return([project])
        expect(action).to receive(:call)
        subject.with(details, action)
      end

      it 'raises exception when no matching projects found' do
        expect(get_jenkins_projects).to receive(:matching_uri).with(details).and_return([])
        allow(project).to receive(:matches?) { true }
        expect(action).not_to receive(:call)
        expect { subject.with(details, action) }.to raise_exception(NotFoundException)
      end
    end

    context 'when automatic project creation is online' do

      before(:each) do
        allow(Java.jenkins.model.Jenkins).to receive(:instance) { jenkins_instance }
        allow(jenkins_instance).to receive(:descriptor) { AutocreateHookDescriptor.new }
      end

      it 'searches exactly matching projects' do
        expect(get_jenkins_projects).to receive(:matching_uri).with(details).and_return([project])
        allow(project).to receive(:matches?) { true }
        expect(create_project_for_branch).not_to receive(:with)
        expect(action).to receive(:call)
        subject.with(details, action)
      end

      it 'creates a new project when no matching projects found' do
        expect(get_jenkins_projects).to receive(:matching_uri).with(details).and_return([project])
        allow(project).to receive(:matches?) { false }
        expect(create_project_for_branch).to receive(:with).with(details).and_return(project)
        expect(action).to receive(:call).with(project, details).once
        subject.with(details, action)
      end
    end
  end
end
