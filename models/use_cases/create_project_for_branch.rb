require_relative '../settings'
require_relative '../project'
require_relative '../exceptions/not_found_exception'
require_relative '../exceptions/configuration_exception'
require_relative '../services/get_jenkins_projects'

include Java

java_import Java.hudson.plugins.git.GitSCM
java_import Java.hudson.plugins.git.BranchSpec
java_import Java.hudson.plugins.git.UserRemoteConfig
java_import Java.hudson.plugins.git.browser.GitLab
java_import Java.hudson.plugins.git.util.DefaultBuildChooser

module GitlabWebHook
  class CreateProjectForBranch
    def with(details)
      copy_from = find_master_project(details)

      new_project_name = "#{Settngs.user_master_project_name ? copy_from.name : details.repository_name}_#{details.safe_branch}"

      # check if new project title already exists (this means that repo url and branch is not matched but the project name exists)
      GetJenkinsProjects.new.all.each do |project|
        raise ConfigurationException.new("project #{new_project_name} already exists but doesn't match the repo url #{details.repository_url} and #{details.branch} branch, can't create the new project") if project.name == new_project_name
      end

      # TODO: set github url, requires github plugin reference
      branch_project = Java.jenkins.model.Jenkins.instance.copy(copy_from.jenkins_project, new_project_name)
      branch_project.scm = prepare_scm_from(copy_from.scm, details)
      branch_project.makeDisabled(false)
      branch_project.description = Settings.description
      branch_project.save

      Project.new(branch_project)
    end

    private

    # TODO move this to GetJenkinsProjects !!!
    def find_master_project(details)
      repo_uri = URIish.new(details.repository_url)
      # find project for the repo and master branch
      all_projects = GetJenkinsProjects.new.all
      master_project = all_projects.find { |project| project.matches?(repo_uri, Settings.master_branch) }
      # use any other branch matching the repo
      unless master_project
        master_project = all_projects.find { |project| project.matches?(repo_uri, Settings.any_branch_pattern) }
      end

      raise NotFoundException.new("could not determine master project, please create a project for the repo (usually for the master branch)") unless master_project
      raise ConfigurationException.new("master project found: #{master_project}, but is not a Git type of project, can't proceed") unless master_project.is_git?

      master_project
    end

    def prepare_scm_from(source_scm, details)
      scm_name = source_scm.getScmName() && source_scm.getScmName().size > 0 ? "#{source_scm.getScmName()}_#{details.branch}" : nil

      # refspec is skipped, we will build specific commit branch
      remote_url, remote_name, remote_refspec = nil, nil, nil
      source_scm.getUserRemoteConfigs().first.tap do |config|
        remote_url = config.getUrl()
        remote_name = config.getName()
      end
      raise ConfigurationException("remote repo clone url not found") unless remote_url

      remote_branch = remote_name && remote_name.size > 0 ? "#{remote_name}/#{details.branch}" : details.branch

      GitSCM.new(
          scm_name,
          [UserRemoteConfig.new(remote_url, remote_name, remote_refspec)],
          [BranchSpec.new(remote_branch)],
          source_scm.getUserMergeOptions(),
          source_scm.getDoGenerate(),
          source_scm.getSubmoduleCfg(),
          source_scm.getClean(),
          source_scm.getWipeOutWorkspace(),
          DefaultBuildChooser.new,
          GitLab.new(details.repository_homepage),
          source_scm.getGitTool,
          source_scm.getAuthorOrCommitter(),
          source_scm.getRelativeTargetDir(),
          source_scm.getReference(),
          source_scm.getExcludedRegions(),
          source_scm.getExcludedUsers(),
          source_scm.getLocalBranch(),
          source_scm.getDisableSubmodules(),
          source_scm.getRecursiveSubmodules(),
          source_scm.getPruneBranches(),
          source_scm.getRemotePoll(),
          source_scm.getGitConfigName(),
          source_scm.getGitConfigEmail(),
          source_scm.getSkipTag(),
          source_scm.getIncludedRegions(),
          source_scm.isIgnoreNotifyCommit(),
          source_scm.getUseShallowClone()
      )
    end
  end
end