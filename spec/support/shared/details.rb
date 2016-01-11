RSpec.shared_context 'details' do
  let (:payload) { JSON.parse(File.read('spec/fixtures/default_payload.json')) }
  let (:details) { GitlabWebHook::PayloadRequestDetails.new(payload) }
end
