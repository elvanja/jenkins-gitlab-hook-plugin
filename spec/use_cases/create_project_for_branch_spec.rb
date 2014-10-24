require 'spec_helper'

require 'models/root_action_descriptor'

module GitlabWebHook
  describe CreateProjectForBranch do
    let(:details) { double(RequestDetails, repository_name: 'discourse', safe_branch: 'features_meta') }
    let(:jenkins_project) { double(AbstractProject) }
    let(:master) { double(Project, name: 'discourse', jenkins_project: jenkins_project) }
    let(:get_jenkins_projects) { double(GetJenkinsProjects, master: master, named: []) }
    let(:subject) { CreateProjectForBranch.new(get_jenkins_projects) }
    let(:jenkins_instance) { double(Java.jenkins.model.Jenkins) }

    before(:each) do
      allow(Java.jenkins.model.Jenkins).to receive(:instance) { jenkins_instance }
      allow(jenkins_instance).to receive(:descriptor) { GitlabWebHookRootActionDescriptor.new }
    end

    context 'when not able to find a master project to copy from' do
      it 'raises appropriate exception' do
        allow(get_jenkins_projects).to receive(:master).with(details) { nil }
        expect { subject.with(details) }.to raise_exception(NotFoundException)
      end
    end

    context 'when branch project already exists' do
      it 'raises appropriate exception' do
        allow(get_jenkins_projects).to receive(:named) { [double] }
        expect { subject.with(details) }.to raise_exception(ConfigurationException)
      end
    end

    context 'when naming the branch project' do

      it 'uses master project name with appropriate settings' do
        expect(subject.send(:get_new_project_name, master, details)).to match(master.name)
      end

      it 'uses repository name with appropriate settings' do
        expect(subject.send(:get_new_project_name, master, details)).to match(details.repository_name)
      end
    end

    context 'when creating the branch project' do
      let(:remote_config) { double(getUrl: 'http://localhost/diaspora', getName: 'Diaspora') }
      let(:source_scm) { double(getScmName: 'git', getUserRemoteConfigs: [remote_config]).as_null_object }
      let(:jenkins_instance) { double(Java.jenkins.model.Jenkins) }
      let(:new_jenkins_project) { double(AbstractProject).as_null_object }

      before(:each) do
        allow(master).to receive(:scm) { source_scm }
        allow(Java.jenkins.model.Jenkins).to receive(:instance) { jenkins_instance }
        expect(jenkins_instance).to receive(:copy).with(jenkins_project, anything).and_return(new_jenkins_project)
      end

      it 'fails if remote url could not be determined' do
        allow(remote_config).to receive(:getUrl) { nil }
        expect { subject.with(details) }.to raise_exception(ConfigurationException)
      end

      it 'returns a new project' do
        allow(subject).to receive(:prepare_scm_from) { double(GitSCM) }
        branch_project = subject.with(details)
        expect(branch_project).to be_kind_of(Project)
        expect(branch_project.jenkins_project).to eq(new_jenkins_project)
      end
    end
  end
end
