require 'spec_helper'

module GitlabWebHook
  describe ProcessCommit do
    include_context 'settings'
    include_context 'projects'
    include_context 'details'

    let(:action) { double(Proc) }
    let(:get_jenkins_projects) { GetJenkinsProjects.new }
    let(:create_project_for_branch) { double(CreateProjectForBranch) }
    let(:subject) { ProcessCommit.new(get_jenkins_projects, create_project_for_branch) }

    before(:each) { allow(get_jenkins_projects).to receive(:all) { all_projects } }

    context 'with related projects' do
     it 'calls action with found project and related details' do
        expect(action).to receive(:call).with(matching_project, details)
        subject.with(details, action)
      end

      it 'returns messages collected by calls to action' do
        expect(action).to receive(:call).with(matching_project, details).and_return('executed')
        expect(subject.with(details, action)).to eq(%w(executed))
      end
    end

    context 'when automatic project creation is offline' do

      it 'searches matching projects' do
        expect(action).to receive(:call)
        subject.with(details, action)
      end

      it 'raises exception when no matching projects found' do
        all_projects.delete(matching_project)
        expect(action).not_to receive(:call)
        expect { subject.with(details, action) }.to raise_exception(NotFoundException)
      end
    end

    context 'when automatic project creation is online' do
      let(:new_project) { double(Project) }
      before(:each) { allow(settings).to receive(:automatic_project_creation?) { true } }

      it 'searches exactly matching projects' do
        expect(create_project_for_branch).not_to receive(:with)
        expect(action).to receive(:call)
        subject.with(details, action)
      end

      it 'creates a new project when no matching projects found' do
        all_projects.delete(matching_project)
        expect(create_project_for_branch).to receive(:with).with(details).and_return(new_project)
        expect(action).to receive(:call).with(new_project, details).once
        subject.with(details, action)
      end
    end
  end
end
