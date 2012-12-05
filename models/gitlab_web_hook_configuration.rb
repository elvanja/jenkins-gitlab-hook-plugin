class GitlabWebHookConfiguration < Java.jenkins.model.GlobalConfiguration
  include Jenkins::Model::DescribableNative

  def self.getDisplayName()
    "Gtilab Global configuration"
  end
end
