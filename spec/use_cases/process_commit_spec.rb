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
        messages = subject.with(details, action)
        expect(messages.size).to eq(1)
        expect(messages).to eq(%w(executed))
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

    context 'with push from unknown repository' do
      let(:new_project) { double(Project) }
      let(:templated_jobs) { { 'matchstr' => 'job-template'} }
      let(:templated_groups) { { 'matchstr' => 'group-template'} }

      before(:each) do
        all_projects.delete(matching_project)
        all_projects.delete(not_matching_project)
        allow(settings).to receive(:templated_jobs).and_return( templated_jobs )
        allow(settings).to receive(:templated_groups).and_return( templated_groups )
      end

      context 'and a template matches repository name' do
        let(:templated_jobs) { { 'Dias' => 'reponame-template'} }

        it 'returns the jobname template' do
          expect(settings).not_to receive(:templated_groups)
          expect(settings).not_to receive(:template_fallback)
          expect(create_project_for_branch).to receive(:from_template).with('reponame-template', details).and_return(new_project)
          expect(action).to receive(:call)
          subject.with(details, action)
        end
      end

      context 'and repo namespace matches some template' do
        let(:templated_groups) { { 'diaspora' => 'repogroup-template' } }

        it 'returns the groupname template' do
          expect(settings).not_to receive(:template_fallback)
          expect(create_project_for_branch).to receive(:from_template).with('repogroup-template', details).and_return(new_project)
          expect(action).to receive(:call)
          subject.with(details, action)
        end
      end

      context 'and fallback template exists' do
        it 'returns the groupname template' do
          expect(settings).to receive(:template_fallback).twice.and_return( 'fallback-template' )
          expect(create_project_for_branch).to receive(:from_template).with('fallback-template', details).and_return(new_project)
          expect(action).to receive(:call)
          subject.with(details, action)
        end
      end

      it 'raises exception when no matching projects found' do
        expect(action).not_to receive(:call)
        expect { subject.with(details, action) }.to raise_exception(NotFoundException)
      end

    end
  end
end
