require 'jenkins/rack'

module Jenkins
  module Model
    class UnprotectedRootAction
      include Jenkins::Model::Action
    end

    class UnprotectedRootActionProxy
      include ActionProxy
      include Java.hudson.model.UnprotectedRootAction
      proxy_for Jenkins::Model::UnprotectedRootAction
    end
  end
end

class GitlabWebHookRootAction < Jenkins::Model::UnprotectedRootAction
  include Jenkins::RackSupport

  display_name "Gitlab Web Hook"
  icon nil # we don't need the link in the main navigation
  url_path "gitlab"

  def call(env)
    GitlabWebHookApi.new.call(env)
  end
end

Jenkins::Plugin.instance.register_extension(GitlabWebHookRootAction.new)
