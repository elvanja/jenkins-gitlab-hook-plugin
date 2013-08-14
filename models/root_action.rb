require 'jenkins/rack'

require_relative 'unprotected_root_action'
require_relative 'api'

class GitlabWebHookRootAction < Jenkins::Model::UnprotectedRootAction
  include Jenkins::RackSupport

  display_name "Gitlab Web Hook"
  icon nil # we don't need the link in the main navigation
  url_path "gitlab"

  def call(env)
    GitlabWebHook::Api.new.call(env)
  end
end

Jenkins::Plugin.instance.register_extension(GitlabWebHookRootAction.new)
