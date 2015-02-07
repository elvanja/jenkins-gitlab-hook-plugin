require 'spec_helper'

module GitlabWebHook
  describe GetJenkinsProjects do
    include_context 'settings'

    before(:each) { allow(subject).to receive(:log_matched) {} }

    context 'when fetching projects by request details' do
      include_context 'projects'
      include_context 'details'

      before(:each) { allow(subject).to receive(:all) { all_projects } }

      it 'finds projects matching details' do
        projects = subject.matching(details)
        expect(projects.size).to eq(1)
        expect(projects[0]).to eq(matching_project)
      end

      it 'finds projects matching details exactly' do
        projects = subject.exactly_matching(details)
        expect(projects.size).to eq(1)
        expect(projects[0]).to eq(matching_project)
      end
    end

    context 'when fetching master project matching request details' do
      include_context 'projects'
      include_context 'details'

      before(:each) { allow(subject).to receive(:all) { all_projects } }

      it 'finds project matching details and master branch' do
        expect(subject.master(details)).to eq(matching_project)
      end

      it 'finds first projects matching details and any non master branch' do
        expect(matching_project).to receive(:matches?).with(anything, anything, anything, true).and_return(false)
        expect(subject.master(details)).to eq(not_matching_project)
      end
    end

    context 'when fetching projects by name' do
      include_context 'projects'

      before(:each) { allow(subject).to receive(:all) { all_projects } }

      it 'finds project by name' do
        projects = subject.named('matching project')
        expect(projects.size).to eq(1)
        expect(projects[0].name).to eq('matching project')
      end

      it 'does not find project by name' do
        projects = subject.named('undefined project')
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
