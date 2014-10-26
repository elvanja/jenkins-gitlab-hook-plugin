module GitlabWebHook
  module Settings
    def settings
      Java.jenkins.model.Jenkins.instance.descriptor(GitlabWebHookRootActionDescriptor.java_class)
    end
  end
end