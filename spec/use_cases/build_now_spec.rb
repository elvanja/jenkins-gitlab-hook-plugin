require 'spec_helper'

module GitlabWebHook
  describe BuildNow do
    let(:details) { double(RequestDetails, payload: double) }
    let(:project) { double(Project, ignore_notify_commit?: false, buildable?: true, getQuietPeriod: double, has_changes?: true) }
    let(:logger) { double }
    let(:subject) { BuildNow.new(project, logger) }

    context 'when project configured to ignore notify commit' do
      it 'skips the build' do
        allow(project).to receive(:ignore_notify_commit?) { true }
        expect(project).not_to receive(:scheduleBuild2)
        expect(subject.with(details, GetBuildActions.new, GetBuildCause.new)).to match('configured to ignore notify commit')
      end
    end

    context 'when project not buildable' do
      it 'skips the build' do
        allow(project).to receive(:buildable?) { false }
        expect(project).not_to receive(:scheduleBuild2)
        expect(subject.with(details, GetBuildActions.new, GetBuildCause.new)).to match('not buildable')
      end
    end

    context 'when no changes detected' do
      it 'skips the build' do
        allow(project).to receive(:has_changes?) { false }
        expect(project).not_to receive(:scheduleBuild2)
        expect(subject.with(details, GetBuildActions.new, GetBuildCause.new)).to match('no SCM changes')
      end
    end

    context 'when build triggered' do
      let(:cause_builder) { double }
      let(:actions_builder) { double }

      before(:each) do
        expect(cause_builder).to receive(:with).with(details)
        expect(actions_builder).to receive(:with).with(project, details)
      end

      context 'successfully' do
        it 'schedules the build' do
          expect(project).to receive(:scheduleBuild2).and_return(true)
          expect(subject.with(details, cause_builder, actions_builder)).to match('scheduled for build')
        end
      end

      context 'unsuccessfully' do
        before(:each) do
          exception = java.lang.Exception.new('message')
          expect(project).to receive(:scheduleBuild2).and_raise(exception)

          severe = Proc.new {}
          expect(severe).to receive(:call).with(Level::SEVERE, 'message', exception)

          expect(logger).to receive(:java_method).with(:log, [Level, java.lang.String, java.lang.Throwable]).and_return(severe)
        end

        it 'logs error' do
          subject.with(details, cause_builder, actions_builder)
        end

        it 'returns appropriate message' do
          expect(subject.with(details, cause_builder, actions_builder)).to match('could not be scheduled for build')
        end
      end
    end

    context 'when validating' do
      it 'requires project' do
        expect { BuildNow.new(nil) }.to raise_exception(ArgumentError)
      end

      it 'requires details' do
        expect { subject.with(nil, GetBuildActions.new, GetBuildCause.new) }.to raise_exception(ArgumentError)
      end
    end
  end
end
