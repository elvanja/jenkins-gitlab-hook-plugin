include Java

java_import Java.hudson.security.csrf.CrumbExclusion

require_relative 'root_action'

class GitlabWebHookCrumbExclusion < CrumbExclusion
  def process(request, response, chain)
    return false unless request.getPathInfo().to_s.start_with?(exclusion_path())
    chain.doFilter(request, response)
    true
  end

  private

  def exclusion_path
    "/#{GitlabWebHookRootAction::WEB_HOOK_ROOT_URL}/"
  end
end

Jenkins::Plugin.instance.register_extension(GitlabWebHookCrumbExclusion.new)
