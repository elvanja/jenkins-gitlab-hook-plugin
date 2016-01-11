require 'spec_helper'

# NOTE : Since 1.565, implementation of RemoteCause.getShortDescription
# calls Jenkins.getInstance().getMarkupFormatter(), with no simple mockup, so
# we test for addr and note accessors

module GitlabWebHook
  describe GetBuildCause do
    let(:repository_uri) { RepositoryUri.new('git@example.com:diaspora/diaspora.git') }
    let(:details) { double(RequestDetails, payload: nil, repository_uri: repository_uri) }
    let(:cause) { subject.with(details) }

    context 'with repository details' do
      it 'contains repository host' do
        expect(cause.addr).to match('example.com')
      end
    end

    context 'with no payload' do
      it 'contains default message' do
        expect(cause.note).to match('no payload available')
      end
    end

    context 'with payload' do
      include_context 'details'
      it 'contains payload details' do
        cause = subject.with(details)
        expect(cause.note).not_to match('no payload available')
        expect(cause.note).to match('branch master with 2 commits')
      end
      include_context 'mr_details'
      it 'contains merge request payload details' do
        cause = subject.with(mr_details)
        expect(cause.note).not_to match('no payload available')
        expect(cause.note).to match('triggered by merge request')
      end
    end

    context 'when validating' do
      it 'requires details' do
        expect { subject.with(nil) }.to raise_exception(ArgumentError)
      end
    end
  end
end
