require 'spec_helper'

module GitlabWebHook
  describe ParseRequest do
    let(:parameters) { JSON.parse(File.read('spec/fixtures/default_params.json')) }
    let(:request) { OpenStruct.new(body: File.new('spec/fixtures/default_payload.json')) }

    context 'with data from params' do
      it 'builds parameters influenced details' do
        details = subject.from(parameters, nil)
        expect(details.repository_url).to eq('http://localhost/peronospora')
      end
    end

    context 'with data from request' do
      it 'builds payload influenced details' do
        details = subject.from({}, request)
        expect(details.repository_url).to eq('git@example.com:diaspora.git')
      end
    end
  end
end