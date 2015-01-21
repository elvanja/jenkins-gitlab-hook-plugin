require 'spec_helper'

module GitlabWebHook
  describe CreateProjectForBranch do
    include_context 'settings'
    include_context 'projects'

    let(:repository_uri) { RepositoryUri.new('http://example.com/discourse/discourse.git') }
    let(:details) { double(PayloadRequestDetails, repository_uri: repository_uri, repository_name: 'discourse', safe_branch: 'features_meta', full_branch_reference: 'refs/heads/features/meta') }
    let(:master) { double(Project, name: 'discourse', jenkins_project: java_project1) }
    let(:get_jenkins_projects) { GetJenkinsProjects.new }
    let(:build_scm) { double(BuildScm, with: double(GitSCM)) }
    let(:subject) { CreateProjectForBranch.new(get_jenkins_projects, build_scm) }

    before(:each) { allow(get_jenkins_projects).to receive(:all) { all_projects } }

    context 'when not able to find a master project to copy from' do
      it 'raises appropriate exception' do
        all_projects.delete(autocreate_match_project)
        expect { subject.with(details) }.to raise_exception(NotFoundException)
      end
    end

    context 'when branch project already exists' do
      it 'raises appropriate exception' do
        expect(get_jenkins_projects).to receive(:named).and_return([not_matching_project])
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
      let(:scm) { double(GitSCM) }
      let(:jenkins_instance) { double(Java.jenkins.model.Jenkins) }
      let(:new_jenkins_project) { double(Java.hudson.model.AbstractProject, scm: scm).as_null_object }

      before(:each) do
        allow(master).to receive(:scm) { scm }
        allow(scm).to receive(:java_kind_of?).with(GitSCM) { true }
        allow(scm).to receive(:java_kind_of?).with(MultiSCM) { false }
        allow(Java.jenkins.model.Jenkins).to receive(:instance) { jenkins_instance }
        expect(get_jenkins_projects).to receive(:master).and_return( master )
        expect(jenkins_instance).to receive(:copy).with(java_project1, anything).and_return(new_jenkins_project)
      end

      it 'returns a new project' do
        branch_project = subject.with(details)
        expect(branch_project).to be_kind_of(Project)
        expect(branch_project.jenkins_project).to eq(new_jenkins_project)
      end
    end
  end
end
