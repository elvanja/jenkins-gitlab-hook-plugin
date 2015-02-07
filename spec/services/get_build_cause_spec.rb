require 'spec_helper'

module GitlabWebHook
  describe GetBuildCause do
    let(:repository_uri) { RepositoryUri.new('git@example.com:diaspora.git') }
    let(:details) { double(RequestDetails, payload: nil, repository_uri: repository_uri) }
    let(:cause) { subject.with(details) }

    context 'with repository details' do
      it 'contains repository host' do
        expect(cause.shortDescription).to match('example.com')
      end
    end

    context 'with no payload' do
      it 'contains default message' do
        expect(cause.shortDescription).to match('no payload available')
      end
    end

    context 'with payload' do
      include_context 'details'
      it 'contains payload details' do
        expect(cause.shortDescription).not_to match('no payload available')
        expect(cause.shortDescription).to match('commits/b6568db1bc1dcd7f8b4d5a946b0b91f9dacd7327')
      end
    end

    context 'when validating' do
      it 'requires details' do
        expect { subject.with(nil) }.to raise_exception(ArgumentError)
      end
    end
  end
end
