require 'spec_helper'

module GitlabWebHook
  describe NotifyCommit do
    let(:project) { double(Project, ignore_notify_commit?: false, buildable?: true) }
    let(:logger) { double }
    let(:subject) { NotifyCommit.new(project, logger) }

    context 'when project configured to ignore notify commit' do
      it 'skips the build' do
        allow(project).to receive(:ignore_notify_commit?) { true }
        expect(project).not_to receive(:schedulePolling)
        expect(subject.call).to match('configured to ignore notify commit')
      end
    end

    context 'when project not buildable' do
      it 'skips the build' do
        allow(project).to receive(:buildable?) { false }
        expect(project).not_to receive(:schedulePolling)
        expect(subject.call).to match('not buildable')
      end
    end

    context 'when notify commit triggered' do
      context 'successfully' do
        it 'schedules polling' do
          expect(project).to receive(:schedulePolling).and_return(true)
          expect(subject.call).to match('scheduled for polling')
        end
      end

      context 'unsuccessfully' do
        before(:each) do
          exception = java.lang.Exception.new('message')
          expect(project).to receive(:schedulePolling).and_raise(exception)

          severe = Proc.new {}
          expect(severe).to receive(:call).with(Java.java.util.logging.Level::SEVERE, 'message', exception)

          expect(logger).to receive(:java_method).with(:log, [Java.java.util.logging.Level, java.lang.String, java.lang.Throwable]).and_return(severe)
        end

        it 'logs error' do
          subject.call
        end

        it 'returns appropriate message' do
          expect(subject.call).to match('could not be scheduled for polling')
        end
      end
    end
  end
end
