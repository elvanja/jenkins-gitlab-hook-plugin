require 'spec_helper'

module GitlabWebHook
  describe Project do
    let(:jenkins_project) { double(AbstractProject, :fullName => "diaspora") }
    let(:logger) { double }
    let(:subject) { Project.new(jenkins_project, logger) }

    context "when initializing" do
      it "requires jenkins project" do
        expect { Project.new(nil) }.to raise_exception(ArgumentError)
      end
    end

    context "when exposing jenkins project interface" do
      [:scm, :schedulePolling, :scheduleBuild2, :fullName, :isParameterized, :isBuildable, :getQuietPeriod, :getProperty, :delete, :description].each do |message|
        it "delegates #{message}" do
          expect(jenkins_project).to receive(message)
          subject.send(message)
        end
      end

      {:is_parametrized? => :isParameterized, :is_buildable? => :isBuildable, :name => :fullName, :to_s => :fullName}.each do |aliased, original|
        it "has nicer alias for #{original}" do
          expect(jenkins_project).to receive(original)
          subject.send(aliased)
        end
      end
    end

    context "when determining if matches repository url and branch" do
      let(:scm) { double(GitSCM) }
      let(:repository) { double("RemoteConfig", :name => "origin", :getURIs => [URIish.new("http://localhost/diaspora")]) }
      let(:branch) { double("BranchSpec", :matches => true) }
      let(:build_chooser) { double("BuildChooser") }

      before (:each) do
        subject.stub(:is_buildable?).and_return(true)
        subject.stub(:is_parametrized?).and_return(false)

        build_chooser.stub(:java_kind_of?).with(InverseBuildChooser).and_return(false)

        scm.stub(:java_kind_of?).with(GitSCM).and_return(true)
        scm.stub(:repositories).and_return([repository])
        scm.stub(:branches).and_return([branch])
        scm.stub(:buildChooser).and_return(build_chooser)

        jenkins_project.stub(:scm).and_return(scm)
      end

      context "it is not matching" do
        it "when it is not buildable" do
          subject.stub(:is_buildable?).and_return(false)
          expect(subject.matches?(anything, anything)).to be_false
        end

        it "when it is not git" do
          scm.stub(:java_kind_of?).with(GitSCM).and_return(false)
          expect(subject.matches?(anything, anything)).to be_false
        end

        it "when repo uris do not match" do
          repository.stub(:getURIs).and_return([URIish.new("http://localhost/other")])
          expect(subject.matches?("http://localhost/diaspora", anything)).to be_false
        end

        it "when branches do not match" do
          branch.stub(:matches).and_return(false)
          expect(logger).to receive(:info)
          expect(subject.matches?("http://localhost/diaspora", anything)).to be_false
        end
      end

      context "it matches" do
        before(:each) do
          expect(logger).to receive(:info)
        end

        it "when is buildable, is git, repo uris match and branches match" do
          expect(subject.matches?("http://localhost/diaspora", anything)).to be_true
        end

        it "when repo uris are local file system paths" do
          repository.stub(:getURIs).and_return([URIish.new("/git/foo.git")])
          expect(subject.matches?("/git/foo.git", anything)).to be_true
        end
      end

      context "when parametrized" do
        let(:branch_name_parameter) { double(ParametersDefinitionProperty, :name => "BRANCH_NAME") }

        before(:each) do
          branch_name_parameter.stub(:java_kind_of?).with(StringParameterDefinition).and_return(true)

          other_parameter = double(ParametersDefinitionProperty, :name => "OTHER_PARAMETER")
          other_parameter.stub(:java_kind_of?).with(StringParameterDefinition).and_return(true)

          branch.stub(:matches).and_return(false)
          branch.stub(:name).and_return("origin/$BRANCH_NAME")

          subject.stub(:is_parametrized?).and_return(true)
          subject.stub(:get_default_parameters).and_return([branch_name_parameter, other_parameter])
        end

        it "does not match when branch parameter not found" do
          branch_name_parameter.stub(:name).and_return("NOT_BRANCH_PARAMETER")
          expect(logger).to receive(:info)
          expect(subject.matches?("http://localhost/diaspora", anything)).to be_false
        end

        it "raises exception when branch parameter is not of supported type" do
          branch_name_parameter.stub(:java_kind_of?).with(StringParameterDefinition).and_return(false)
          expect { subject.matches?("http://localhost/diaspora", anything) }.to raise_exception(ConfigurationException)
        end

        it "matches when branch parameter found and is of supported type" do
          expect(logger).to receive(:info)
          expect(subject.matches?("http://localhost/diaspora", anything)).to be_true
        end

        it "supports parameter usage without $" do
          branch.stub(:name).and_return("origin/BRANCH_NAME")
          expect(logger).to receive(:info)
          expect(subject.matches?("http://localhost/diaspora", anything)).to be_true
        end
      end

      context "when matching exactly" do
        it "does not match when branches are not equal" do
          branch.stub(:name).and_return("origin/**")
          expect(logger).to receive(:info)
          expect(subject.matches?("http://localhost/diaspora", "origin/master", true)).to be_false
        end

        it "matches when branches are equal" do
          branch.stub(:name).and_return("origin/master")
          expect(logger).to receive(:info)
          expect(subject.matches?("http://localhost/diaspora", "origin/master", true)).to be_false
        end
      end

      context "with inverse match strategy" do
        before(:each) do
          build_chooser.stub(:java_kind_of?).with(InverseBuildChooser).and_return(true)
          expect(logger).to receive(:info)
        end

        it "does not match when regular strategy would match" do
          expect(subject.matches?("http://localhost/diaspora", anything)).to be_false
        end

        it "matches when regular strategy would not match" do
          branch.stub(:matches).and_return(false)
          expect(subject.matches?("http://localhost/diaspora", anything)).to be_true
        end
      end
    end
  end
end
