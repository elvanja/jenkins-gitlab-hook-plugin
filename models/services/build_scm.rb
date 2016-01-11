require_relative '../values/scm_data'

include Java

java_import Java.hudson.plugins.git.GitSCM
java_import Java.hudson.plugins.git.BranchSpec
java_import Java.hudson.plugins.git.UserRemoteConfig
java_import Java.hudson.plugins.git.browser.GitLab
java_import Java.hudson.plugins.git.util.DefaultBuildChooser
java_import Java.hudson.util.VersionNumber


module GitlabWebHook
  class BuildScm

    def with(source_scm, details, is_template=false)
      # refspec is skipped, we will build specific commit branch
      scm_data = ScmData.new(source_scm, details, is_template)

      build_scm(scm_data)
    end

    private

    def build_scm(scm_data)
      GitSCM.new(
          java.util.ArrayList.new([UserRemoteConfig.new(scm_data.url, scm_data.name, scm_data.refspec, scm_data.credentials).java_object]),
          scm_data.branchlist,
          scm_data.source_scm.isDoGenerateSubmoduleConfigurations(),
          scm_data.source_scm.getSubmoduleCfg(),
          scm_data.source_scm.getBrowser(),
          scm_data.source_scm.getGitTool(),
          scm_data.source_scm.getExtensions()
      )
    end
  end
end
