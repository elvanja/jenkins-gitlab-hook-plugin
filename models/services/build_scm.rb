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
    GIT_PLUGIN_VERSION_WITH_NEW_FEATURES = '1.9.9'

    def with(source_scm, details, gitplugin = Java.jenkins.model.Jenkins.instance.getPluginManager().getPlugin('git'), is_template=false)
      # refspec is skipped, we will build specific commit branch
      scm_data = ScmData.new(source_scm, details, is_template)

      if gitplugin.isOlderThan(VersionNumber.new(GIT_PLUGIN_VERSION_WITH_NEW_FEATURES))
        build_legacy_scm(scm_data)
      else
        build_scm(scm_data)
      end
    end

    private

    def build_scm(scm_data)
      GitSCM.new(
          [UserRemoteConfig.new(scm_data.url, scm_data.name, scm_data.credentials)],
          scm_data.branchlist,
          scm_data.source_scm.isDoGenerateSubmoduleConfigurations(),
          scm_data.source_scm.getSubmoduleCfg(),
          scm_data.source_scm.getBrowser(),
          scm_data.source_scm.getGitTool(),
          scm_data.source_scm.getExtensions()
      )
    end

    def build_legacy_scm(scm_data)
      GitSCM.new(
          scm_data.source_scm.getScmName().to_s.size > 0 ? "#{scm_data.source_scm.getScmName()}_#{scm_data.details.safe_branch}" : nil,
          [UserRemoteConfig.new(scm_data.url, scm_data.name, nil)],
          scm_data.branchlist,
          scm_data.source_scm.getUserMergeOptions(),
          scm_data.source_scm.getDoGenerate(),
          scm_data.source_scm.getSubmoduleCfg(),
          scm_data.source_scm.getClean(),
          scm_data.source_scm.getWipeOutWorkspace(),
          DefaultBuildChooser.new,
          GitLab.new(scm_data.details.repository_homepage),
          scm_data.source_scm.getGitTool,
          scm_data.source_scm.getAuthorOrCommitter(),
          scm_data.source_scm.getRelativeTargetDir(),
          scm_data.source_scm.getReference(),
          scm_data.source_scm.getExcludedRegions(),
          scm_data.source_scm.getExcludedUsers(),
          scm_data.source_scm.getLocalBranch(),
          scm_data.source_scm.getDisableSubmodules(),
          scm_data.source_scm.getRecursiveSubmodules(),
          scm_data.source_scm.getPruneBranches(),
          scm_data.source_scm.getRemotePoll(),
          scm_data.source_scm.getGitConfigName(),
          scm_data.source_scm.getGitConfigEmail(),
          scm_data.source_scm.getSkipTag(),
          scm_data.source_scm.getIncludedRegions(),
          scm_data.source_scm.isIgnoreNotifyCommit(),
          scm_data.source_scm.getUseShallowClone()
      )
    end
  end
end
