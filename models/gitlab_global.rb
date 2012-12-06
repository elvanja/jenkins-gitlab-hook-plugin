module Jenkins
  module Tasks
    class GitlabGlobal
      include Jenkins::Model
      include Jenkins::Model::Describable

      #describe_as Java.hudson.tasks.Builder
      describe_as Java.jenkins.model.GlobalConfiguration

      display_name "Gitlab_web_hook_builder builder"

      def initialize(attrs = {})
        puts "initialized GitlabGlobal"
      end
    end
  end
end

module Jenkins
  module Tasks
    class GitlabGlobalProxy < Java.jenkins.model.GlobalConfiguration
      include Jenkins::Model::DescribableProxy
      proxy_for Jenkins::Tasks::GitlabGlobal
    end
  end
end
