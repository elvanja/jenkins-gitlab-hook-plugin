require_relative '../exceptions/not_found_exception'
require_relative '../exceptions/configuration_exception'
require_relative '../values/settings'
require_relative '../values/project'
require_relative '../services/get_jenkins_projects'

include Java

java_import Java.hudson.plugins.git.GitSCM
java_import Java.hudson.plugins.git.BranchSpec
java_import Java.hudson.plugins.git.UserRemoteConfig
java_import Java.hudson.plugins.git.browser.GitLab
java_import Java.hudson.plugins.git.util.DefaultBuildChooser

module GitlabWebHook
  class CreateProjectForBranch
    def initialize(get_jenkins_projects = GetJenkinsProjects.new)
      @get_jenkins_projects = get_jenkins_projects
    end

    def with(details)
      copy_from = get_project_to_copy_from(details)
      new_project_name = get_new_project_name(copy_from, details)

      # TODO: set github url, requires github plugin reference
      branch_project = Java.jenkins.model.Jenkins.instance.copy(copy_from.jenkins_project, new_project_name)
      branch_project.scm = prepare_scm_from(copy_from.scm, details)
      branch_project.makeDisabled(false)
      branch_project.description = Settings.description
      branch_project.save

      Project.new(branch_project)
    end

    def from_template(template, details)
      # NOTE : returned value is an instance GitlabWebHook::Project, with some methods delegated to real jenkins object
      copy_from = get_template_project(template)
      new_project_name = details.repository_name

      # The SCM related code will fail on 1.x plugins
      remote_url, remote_name, remote_refspec, remote_credentials = nil, nil, nil, nil
      copy_from.scm.get_user_remote_configs.first.tap do |config|
        remote_url = config.getUrl()
        remote_name = config.getName()
        remote_refspec = config.getRefspec()
        remote_credentials = config.getCredentialsId()
      end

      modified_scm = GitSCM.new(
          [UserRemoteConfig.new(remote_url, remote_name, remote_refspec, remote_credentials)],
          [BranchSpec.new('**')], # FIXME : this should be taken from copy_from.scm
          copy_from.scm.isDoGenerateSubmoduleConfigurations(),
          copy_from.scm.getSubmoduleCfg(),
          copy_from.scm.getBrowser(),
          copy_from.scm.getGitTool(),
          copy_from.scm.getExtensions()
        )

      branch_project = Java.jenkins.model.Jenkins.instance.copy(copy_from.jenkins_project, new_project_name)
      branch_project.scm = modified_scm
      branch_project.makeDisabled(false)
      branch_project.save
      Project.new(branch_project)
    end

    private

    def get_project_to_copy_from(details)
      master_not_found_message = 'could not determine master project, please create a project for the repo (usually for the master branch)'
      @get_jenkins_projects.master(details) || raise(NotFoundException.new(master_not_found_message))
    end

    def get_template_project(template)
      raise NotFoundException.new("could not found template '#{template}'") if @get_jenkins_projects.named(template).empty?
      template
    end

    def get_new_project_name(copy_from, details)
      new_project_name = "#{Settings.use_master_project_name? ? copy_from.name : details.repository_name}_#{details.safe_branch}"
      raise ConfigurationException.new("project #{new_project_name} already exists") unless @get_jenkins_projects.named(new_project_name).empty?
      new_project_name
    end

    def prepare_scm_from(source_scm, details)
      scm_name = source_scm.getScmName() && source_scm.getScmName().size > 0 ? "#{source_scm.getScmName()}_#{details.safe_branch}" : nil

      # refspec is skipped, we will build specific commit branch
      remote_url, remote_name, remote_refspec = nil, nil, nil
      source_scm.getUserRemoteConfigs().first.tap do |config|
        remote_url = config.getUrl()
        remote_name = config.getName()
        remote_refspec = config.getRefspec()
      end
      raise ConfigurationException.new('remote repo clone url not found') unless remote_url

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
