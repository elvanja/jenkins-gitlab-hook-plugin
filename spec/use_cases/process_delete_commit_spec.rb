require 'spec_helper'

require 'models/root_action_descriptor'

module GitlabWebHook
  describe ProcessDeleteCommit do
    let(:details) { double(RequestDetails, branch: 'features/meta') }
    let(:get_jenkins_projects) { double(GetJenkinsProjects) }
    let(:subject) { ProcessDeleteCommit.new(get_jenkins_projects) }
    let(:jenkins_instance) { double(Java.jenkins.model.Jenkins) }

    context 'when automatic project creation is offline' do
      it 'skips processing' do
        allow(Java.jenkins.model.Jenkins).to receive(:instance) { jenkins_instance }
        allow(jenkins_instance).to receive(:descriptor) { GitlabWebHookRootActionDescriptor.new }
        expect(get_jenkins_projects).not_to receive(:all)
        expect(subject.with(details).first).to match('automatic branch projects creation is not active')
      end
    end

    context 'when automatic project creation is online' do
      before(:each) do
        allow(Java.jenkins.model.Jenkins).to receive(:instance) { jenkins_instance }
        allow(jenkins_instance).to receive(:descriptor) { AutocreateHookDescriptor.new }
      end

      context 'with master branch in commit' do
        before(:each) { expect(get_jenkins_projects).not_to receive(:all) }

        it 'skips processing' do
          allow(details).to receive(:branch) { AutocreateHookDescriptor.new.master_branch }
          expect(subject.with(details).first).to match('relates to master project')
        end
      end

      context 'with non master branch in commit' do
        let(:project) { double(Project, to_s: 'non_master') }

        before(:each) { expect(get_jenkins_projects).to receive(:all).with(details).and_return([project]) }

        it 'deletes automatically created project' do
          allow(project).to receive(:description) { AutocreateHookDescriptor.new.description }
          expect(project).to receive(:delete)
          expect(subject.with(details).first).to match("deleted #{project} project")
        end

        it 'skips project not automatically created' do
          allow(project).to receive(:description) { 'manually created' }
          expect(project).not_to receive(:delete)
          expect(subject.with(details).first).to match('not automatically created')
        end
      end
    end
  end
end
