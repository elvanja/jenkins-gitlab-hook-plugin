require 'spec_helper'

module GitlabWebHook
  describe BuildScm do
    include_context 'details'
    let(:remote_config) { double(UserRemoteConfig, getCredentialsId: 'id').as_null_object }
    let(:source_scm) { double(GitSCM, getScmName: 'git', getUserRemoteConfigs: [remote_config]) }

    context 'with up to date git plugin' do
      it 'builds up to date git scm' do
        expect(subject).to receive(:build_scm)
        subject.with(source_scm, details, false)
      end
    end
  end
end
