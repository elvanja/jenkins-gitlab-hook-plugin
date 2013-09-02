require 'spec_helper'

module GitlabWebHook
  describe ProcessDeleteCommit do
    let(:details) { double(RequestDetails, :branch => 'features/meta') }
    let(:get_jenkins_projects) { double(GetJenkinsProjects) }
    let(:subject) { ProcessDeleteCommit.new(get_jenkins_projects) }

    context "when automatic project creation is offline" do
      it "skips processing" do
        Settings.stub(:automatic_project_creation?).and_return(false)
        expect(get_jenkins_projects).not_to receive(:exactly_matching)
        expect(subject.with(details).first).to match("automatic branch projects creation is not active")
      end
    end

    context "when automatic project creation is online" do
      before(:each) do
        Settings.stub(:automatic_project_creation?).and_return(true)
      end

      context "with master branch in commit" do
        before(:each) do
          expect(get_jenkins_projects).not_to receive(:exactly_matching)
        end

        it "skips processing" do
          details.stub(:branch).and_return(Settings.master_branch)
          expect(subject.with(details).first).to match("relates to master project")
        end
      end

      context "with non master branch in commit" do
        let(:project) { double(Project, :to_s => "non_master") }

        before(:each) do
          expect(get_jenkins_projects).to receive(:exactly_matching).with(details).and_return([project])
        end

        it "deletes automatically created project" do
          project.stub(:description).and_return(Settings.description)
          expect(project).to receive(:delete)
          expect(subject.with(details).first).to match("deleted #{project} project")
        end

        it "skips project not automatically created" do
          project.stub(:description).and_return("manually created")
          expect(project).not_to receive(:delete)
          expect(subject.with(details).first).to match("not automatically created")
        end
      end
    end
  end
end
