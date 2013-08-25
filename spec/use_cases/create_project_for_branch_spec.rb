require 'spec_helper'

module GitlabWebHook
  describe CreateProjectForBranch do
    let(:details) { double(RequestDetails, :repository_name => 'discourse', :safe_branch => 'features_meta') }
    let(:jenkins_project) { double(AbstractProject) }
    let(:master) { double(Project, :name => 'discourse', :jenkins_project => jenkins_project) }
    let(:get_jenkins_projects) { double(GetJenkinsProjects, :master => master, :named => []) }
    let(:subject) { CreateProjectForBranch.new(get_jenkins_projects) }

    context "when not able to find a master project to copy from" do
      it "raises appropriate exception" do
        get_jenkins_projects.stub(:master).with(details).and_return(nil)
        expect { subject.with(details) }.to raise_exception(NotFoundException)
      end
    end

    context "when branch project already exists" do
      it "raises appropriate exception" do
        get_jenkins_projects.stub(:named).and_return([double])
        expect { subject.with(details) }.to raise_exception(ConfigurationException)
      end
    end

    context "when naming the branch project" do
      it "uses master project name with appropriate settings" do
        Settings.stub(:user_master_project_name).and_return(true)
        expect(subject.send(:get_new_project_name, master, details)).to match(master.name)
      end

      it "uses repository name with appropriate settings" do
        Settings.stub(:user_master_project_name).and_return(true)
        expect(subject.send(:get_new_project_name, master, details)).to match(details.repository_name)
      end
    end

    context "when creating the branch project" do
      let(:remote_config) { double(:getUrl => "http://localhost/diaspora", :getName => "Diaspora") }
      let(:source_scm) { double(:getScmName => "git", :getUserRemoteConfigs => [remote_config]).as_null_object }
      let(:jenkins) { double(Java.jenkins.model.Jenkins) }
      let(:new_jenkins_project) { double(AbstractProject).as_null_object }

      before(:each) do
        master.stub(:scm).and_return(source_scm)
        Java.jenkins.model.Jenkins.stub(:instance).and_return(jenkins)
        expect(jenkins).to receive(:copy).with(jenkins_project, anything).and_return(new_jenkins_project)
      end

      it "fails if remote url could not be determined" do
        remote_config.stub(:getUrl).and_return(nil)
        expect { subject.with(details) }.to raise_exception(ConfigurationException)
      end

      it "returns a new project" do
        subject.stub(:prepare_scm_from).and_return(double(GitSCM))
        branch_project = subject.with(details)
        expect(branch_project).to be_kind_of(Project)
        expect(branch_project.jenkins_project).to eq(new_jenkins_project)
      end
    end
  end
end
