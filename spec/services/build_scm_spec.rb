require 'spec_helper'

module GitlabWebHook
  describe BuildScm do
    let(:git_plugin) { double() }
    let(:details) { double(RequestDetails).as_null_object }
    let(:remote_config) { double(UserRemoteConfig, getCredentialsId: 'id').as_null_object }
    let(:source_scm) { double(GitSCM, getScmName: 'git', getUserRemoteConfigs: [remote_config]).as_null_object }

    context 'with up to date git plugin' do
      before(:each) { expect(git_plugin).to receive(:isOlderThan) { false } }

      it 'builds up to date git scm' do
        expect(subject).to receive(:build_scm)
        subject.with(source_scm, details, git_plugin)
      end
    end

    context 'with legacy git plugin' do
      before(:each) { expect(git_plugin).to receive(:isOlderThan) { true } }

      it 'builds legacy git scm' do
        expect(subject).to receive(:build_legacy_scm)
        subject.with(source_scm, details, git_plugin)
      end
    end
  end
end