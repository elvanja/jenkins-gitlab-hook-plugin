require 'spec_helper'

module GitlabWebHook
  describe BuildNow do
    let(:details) { double(RequestDetails, :payload => double) }
    let(:project) { double(Project, :is_ignoring_notify_commit? => false, :is_buildable? => true, :getQuietPeriod => double) }
    let(:logger) { double }
    let(:subject) { BuildNow.new(project, logger) }

    context "when project configured to ignore notify commit" do
      it "skips the build" do
        project.stub(:is_ignoring_notify_commit?).and_return(true)

        expect(project).not_to receive(:scheduleBuild2)
        expect(subject.with(details, GetBuildActions.new, GetBuildCause.new)).to match("configured to ignore notify commit")
      end
    end

    context "when project not buildable" do
      it "skips the build" do
        project.stub(:is_buildable?).and_return(false)

        expect(project).not_to receive(:scheduleBuild2)
        expect(subject.with(details, GetBuildActions.new, GetBuildCause.new)).to match("not buildable")
      end
    end

    context "when build triggered" do
      let(:cause_builder) { double }
      let(:actions_builder) { double }

      before(:each) do
        expect(cause_builder).to receive(:with).with(details)
        expect(actions_builder).to receive(:with).with(project, details)
      end

      context "successfully" do
        it "schedules the build" do
          expect(project).to receive(:scheduleBuild2).and_return(true)
          expect(subject.with(details, cause_builder, actions_builder)).to match("scheduled for build")
        end
      end

      context "unsuccessfully" do
        it "logs error and returns appropriate message" do
          expect(project).to receive(:scheduleBuild2).and_raise(Exception)
          expect(logger).to receive(:log)
          expect(subject.with(details, cause_builder, actions_builder)).to match("could not be scheduled for build")
        end
      end
    end

    context "when validating" do
      it "requires project" do
        expect { BuildNow.new(nil) }.to raise_exception(ArgumentError)
      end

      it "requires details" do
        expect { subject.with(nil, GetBuildActions.new, GetBuildCause.new) }.to raise_exception(ArgumentError)
      end
    end
  end
end
