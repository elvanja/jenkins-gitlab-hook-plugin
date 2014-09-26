require 'spec_helper'

require 'models/root_action_descriptor'

module GitlabWebHook
  describe CreateProjectForBranch do
    let(:details) { double(RequestDetails, repository_name: 'discourse', safe_branch: 'features_meta', branch: 'features/meta') }
    let(:jenkins_project) { double(AbstractProject) }
    let(:master) { double(Project, name: 'discourse', jenkins_project: jenkins_project) }
    let(:get_jenkins_projects) { double(GetJenkinsProjects, master: master, named: []) }
    let(:build_scm) { double(BuildScm, with: double(GitSCM)) }
    let(:subject) { CreateProjectForBranch.new(get_jenkins_projects, build_scm) }
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
      let(:jenkins_instance) { double(Java.jenkins.model.Jenkins) }
      let(:new_jenkins_project) { double(AbstractProject).as_null_object }

      before(:each) do
        allow(master).to receive(:scm) { double(GitSCM) }
        allow(Java.jenkins.model.Jenkins).to receive(:instance) { jenkins_instance }
        expect(jenkins_instance).to receive(:copy).with(jenkins_project, anything).and_return(new_jenkins_project)
      end

      it 'returns a new project' do
        branch_project = subject.with(details)
        expect(branch_project).to be_kind_of(Project)
        expect(branch_project.jenkins_project).to eq(new_jenkins_project)
      end
    end
  end
end
