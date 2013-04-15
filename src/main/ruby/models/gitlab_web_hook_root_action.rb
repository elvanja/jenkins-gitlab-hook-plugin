require 'jenkins/rack'

class GitlabWebHookRootAction < Jenkins::Model::RootAction
  include Jenkins::RackSupport

  display_name "Gitlab Web Hook"
  icon nil # we don't need the link in the main navigation
  url_path "gitlab"

  def call(env)
    GitlabWebHookApi.new.call(env)
  end
end

Jenkins::Plugin.instance.register_extension(GitlabWebHookRootAction.new)
