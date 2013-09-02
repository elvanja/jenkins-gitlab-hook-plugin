require 'spec_helper'

module GitlabWebHook
  describe GetJenkinsProjects do
    context "when fetching projects by request details" do
      let(:details) { double(RequestDetails, :branch => "master", :repository_uri => double(RepositoryUri)) }
      let(:matching_project) { double(Project) }
      let(:not_matching_project) { double(Project) }

      before(:each) do
        subject.stub(:all).and_return([not_matching_project, matching_project])
      end

      it "finds projects matching details" do
        expect(not_matching_project).to receive(:matches?).with(details.repository_uri, details.branch, false).and_return(false)
        expect(matching_project).to receive(:matches?).with(details.repository_uri, details.branch, false).and_return(true)

        projects = subject.matching(details)
        expect(projects.size).to eq(1)
        expect(projects[0]).to eq(matching_project)
      end

      it "finds projects matching details exactly" do
        expect(not_matching_project).to receive(:matches?).with(details.repository_uri, details.branch, true).and_return(false)
        expect(matching_project).to receive(:matches?).with(details.repository_uri, details.branch, true).and_return(true)

        projects = subject.exactly_matching(details)
        expect(projects.size).to eq(1)
        expect(projects[0]).to eq(matching_project)
      end
    end

    context "when fetching master project matching request details" do
      let(:details) { double(RequestDetails, :branch => "master", :repository_uri => double(RepositoryUri)) }
      let(:matching_project) { double(Project) }
      let(:not_matching_project) { double(Project) }

      before(:each) do
        subject.stub(:all).and_return([not_matching_project, matching_project])
      end

      it "finds project matching details and master branch" do
        expect(not_matching_project).to receive(:matches?).with(details.repository_uri, Settings.any_branch_pattern).and_return(true)
        expect(not_matching_project).to receive(:matches?).with(details.repository_uri, Settings.master_branch, true).and_return(false)
        expect(matching_project).to receive(:matches?).with(details.repository_uri, Settings.any_branch_pattern).and_return(true)
        expect(matching_project).to receive(:matches?).with(details.repository_uri, Settings.master_branch, true).and_return(true)

        expect(subject.master(details)).to eq(matching_project)
      end

      it "finds first projects matching details and any non master branch" do
        expect(not_matching_project).to receive(:matches?).with(details.repository_uri, Settings.any_branch_pattern).and_return(true)
        expect(not_matching_project).to receive(:matches?).with(details.repository_uri, Settings.master_branch, true).and_return(false)
        expect(matching_project).to receive(:matches?).with(details.repository_uri, Settings.any_branch_pattern).and_return(true)
        expect(matching_project).to receive(:matches?).with(details.repository_uri, Settings.master_branch, true).and_return(false)

        expect(subject.master(details)).to eq(not_matching_project)
      end
    end

    context "when fetching projects by name" do
      before(:each) do
        subject.stub(:all).and_return([
          double(Project, :name => "1st"),
          double(Project, :name => "2nd")
        ])
      end

      it "finds project by name" do
        projects = subject.named("2nd")
        expect(projects.size).to eq(1)
        expect(projects[0].name).to eq("2nd")
      end

      it "does not find project by name" do
        projects = subject.named("3rd")
        expect(projects.size).to eq(0)
      end
    end

    context "when fetching all projects from jenkins instance" do
      let(:jenkins) { double(Java.jenkins.model.Jenkins, :getAllItems => []) }

      before(:each) do
        Java.jenkins.model.Jenkins.stub(:instance).and_return(jenkins)
      end

      it "elevates privileges and restores them" do
        expect(subject).to receive(:elevate_priviledges).ordered
        expect(subject).to receive(:revert_priviledges).ordered
        subject.send(:all)
      end

      it "returns custom projects" do
        jenkins.stub(:getAllItems).and_return([
          double(Java.hudson.model.AbstractProject),
          double(Java.hudson.model.AbstractProject)
        ])

        projects = subject.send(:all)
        expect(projects.size).to eq(2)
        projects.each do |project|
          expect(project).to be_kind_of(Project)
        end
      end
    end
  end
end