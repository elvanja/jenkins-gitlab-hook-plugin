RSpec.shared_context 'settings' do
  let(:settings) { GitlabWebHookRootActionDescriptor.new }
  let(:jenkins_instance) { double(Java.jenkins.model.Jenkins) }

  before(:each) do
    allow(Java.jenkins.model.Jenkins).to receive(:instance) { jenkins_instance }
    allow(jenkins_instance).to receive(:descriptor) { settings }
  end
end