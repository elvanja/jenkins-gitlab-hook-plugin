require 'spec_helper'

# NOTE : Since 1.565, implementation of RemoteCause.getShortDescription
# calls Jenkins.getInstance().getMarkupFormatter(), with no simple mockup, so
# we test for addr and note accessors

module GitlabWebHook
  describe GetBuildCause do
    let(:repository_uri) { double(RepositoryUri, host: 'localhost') }
    let(:details) { double(RequestDetails, payload: nil, repository_uri: repository_uri) }

    context 'with repository details' do
      it 'contains repository host' do
        cause = subject.with(details)
        expect(cause.addr).to match('localhost')
      end
    end

    context 'with no payload' do
      it 'contains default message' do
        cause = subject.with(details)
        expect(cause.note).to match('no payload available')
      end
    end

    context 'with payload' do
      it 'contains payload details' do
        allow(details).to receive(:payload) { true }
        allow(details).to receive(:full_branch_reference) { 'master' }
        allow(details).to receive(:commits_count) { 1 }
        allow(details).to receive(:commits) { [double(Commit, url: 'http://localhost/diaspora/peronospora/commits/123456', message: 'fix')] }

        cause = subject.with(details)
        expect(cause.note).not_to match('no payload available')
        expect(cause.note).to match('commits/123456')
      end
    end

    context 'when validating' do
      it 'requires details' do
        expect { subject.with(nil) }.to raise_exception(ArgumentError)
      end
    end
  end
end
