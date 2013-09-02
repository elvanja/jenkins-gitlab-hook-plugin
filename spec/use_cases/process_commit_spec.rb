require 'spec_helper'

module GitlabWebHook
  describe ProcessCommit do
    let(:details) { double(RequestDetails) }
    let(:action) { double(Proc) }
    let(:project) { double(Project) }
    let(:get_jenkins_projects) { double(GetJenkinsProjects) }
    let(:create_project_for_branch) { double(CreateProjectForBranch) }
    let(:subject) { ProcessCommit.new(get_jenkins_projects, create_project_for_branch) }

    context "with related projects" do
      it "calls action with found project and related details" do
        subject.stub(:get_projects_to_process).and_return([project, project])
        expect(action).to receive(:call).with(project, details).twice
        subject.with(details, action)
      end

      it "returns messages collected by calls to action" do
        subject.stub(:get_projects_to_process).and_return([project, project])
        expect(action).to receive(:call).with(project, details).twice.and_return("executed")
        expect(subject.with(details, action)).to eq(["executed", "executed"])
      end
    end

    context "when automatic project creation is offline" do
      before(:each) do
        Settings.stub(:automatic_project_creation?).and_return(false)
        expect(create_project_for_branch).not_to receive(:with)
      end

      it "searches matching projects" do
        expect(get_jenkins_projects).to receive(:matching).with(details).and_return([project])
        expect(action).to receive(:call)
        subject.with(details, action)
      end

      it "raises exception when no matching projects found" do
        expect(get_jenkins_projects).to receive(:matching).with(details).and_return([])
        expect(action).not_to receive(:call)
        expect { subject.with(details, action) }.to raise_exception(NotFoundException)
      end
    end

    context "when automatic project creation is online" do
      before(:each) do
        Settings.stub(:automatic_project_creation?).and_return(true)
      end

      it "searches exactly matching projects" do
        expect(get_jenkins_projects).to receive(:exactly_matching).with(details).and_return([project])
        expect(create_project_for_branch).not_to receive(:with)
        expect(action).to receive(:call)
        subject.with(details, action)
      end

      it "creates a new project when no matching projects found" do
        expect(get_jenkins_projects).to receive(:exactly_matching).with(details).and_return([])
        expect(create_project_for_branch).to receive(:with).with(details).and_return(project)
        expect(action).to receive(:call).with(project, details).once
        subject.with(details, action)
      end
    end
  end
end
