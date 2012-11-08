require 'sinatra/base'

require_relative 'gitlab_project'

include Java

java_import Java.hudson.model.Cause
java_import Java.hudson.model.AbstractProject
java_import Java.hudson.security.ACL

java_import Java.org.eclipse.jgit.transport.URIish
java_import Java.org.acegisecurity.Authentication
java_import Java.org.acegisecurity.context.SecurityContextHolder

java_import Java.hudson.model.ParametersDefinitionProperty
java_import Java.hudson.plugins.git.GitSCM
java_import Java.hudson.plugins.git.BranchSpec
java_import Java.hudson.plugins.git.UserRemoteConfig
java_import Java.hudson.plugins.git.browser.GitLab
java_import Java.hudson.plugins.git.util.DefaultBuildChooser

java_import Java.java.util.logging.Logger

module GitlabWebHook
  class ConfigurationException < Exception; end
  class BadRequestException < Exception; end
  class NotFoundException < Exception; end

  # TODO a hook to delete artifacts from the feature branches would be nice

  # TODO: bring this into the UI / project configuration
  # default params should be available, configuration overrides them
  CREATE_PROJECTS_FOR_NON_MASTER_BRANCHES_AUTOMATICALLY = true
  MASTER_BRANCH = "master"
  USE_MASTER_PROJECT_NAME = false
  DESCRIPTION = "automatically created by Gitlab Web Hook plugin"
  ANY_BRANCH = "**"
end

class GitlabWebHookApi < Sinatra::Base
  LOGGER = Logger.getLogger(GitlabWebHookApi.class.name)

  get '/ping' do
    'Gitlab Web Hook is up and running :-)'
  end

  notify_commit = lambda do
    get_projects_to_process do |project|
      project.notify_commit
    end
  end
  get '/notify_commit', &notify_commit
  post '/notify_commit', &notify_commit

  build_now = lambda do
    get_projects_to_process do |project, repo_url, payload|
      project.build_now(get_build_cause(repo_url, payload), get_commit_branch(payload))
    end
  end
  get '/build_now', &build_now
  post '/build_now', &build_now

  private

  def get_projects_to_process
    # set system priviledges to be able to see all projects
    # see https://wiki.jenkins-ci.org/display/JENKINS/Git+Plugin hudson.plugins.git.GitStatus#doNotifyCommit comments for details
    old_authentication_level = SecurityContextHolder.getContext().getAuthentication()
    SecurityContextHolder.getContext().setAuthentication(ACL::SYSTEM)

    repo_url, payload = get_repo_url_from_params
    LOGGER.info("gitlab web hook triggered for repo url #{repo_url} and #{get_commit_branch(payload)} branch")
    LOGGER.info("with payload: #{payload || "N/A"}")

    messages = []
    if is_delete_branch_commit?(payload)
      messages += process_delete_commit(payload)
    else
      get_projects_for_repo_url_and_commit_branch(repo_url, payload).each do |project|
        messages << yield(project, repo_url, payload)
      end
    end
    LOGGER.info(messages.join("\n"))
    messages.join("<br/>")
  rescue GitlabWebHook::BadRequestException => e
    LOGGER.warning(e.message)
    status 400
    e.message
  rescue GitlabWebHook::NotFoundException => e
    LOGGER.warning(e.message)
    status 404
    e.message
  rescue Exception => e
    LOGGER.severe(e.message)
    status 500
    e.message
  ensure
    SecurityContextHolder.getContext().setAuthentication(old_authentication_level) if old_authentication_level
  end

  def get_repo_url_from_params
    return params[:repo_url] if params[:repo_url] && !params[:repo_url].empty?
    return params[:url] if params[:url] && !params[:url].empty?

    begin
      request.body.rewind
      payload = JSON.parse(request.body.read)
      repo_url = payload["repository"]["url"]
    rescue
    end
    raise GitlabWebHook::BadRequestException.new("repo url not found in Gitlab payload or the Get parameters #{[params.inspect, request.body.read].join(",")}") unless repo_url && !repo_url.empty?

    return repo_url, payload
  end

  def get_projects_for_repo_url_and_commit_branch(repo_url, payload)
    repo_uri = URIish.new(repo_url)
    commit_branch = get_commit_branch(payload)

    projects = all_jenkins_projects.select do |project|
      project.matches_repo_uri_and_branch?(repo_uri, commit_branch)
    end

    if GitlabWebHook::CREATE_PROJECTS_FOR_NON_MASTER_BRANCHES_AUTOMATICALLY
      projects.select! { |project| project.is_exact_match?(commit_branch) }
      projects << create_project_for_branch(repo_url, commit_branch, payload) if projects.empty?
    end

    raise GitlabWebHook::NotFoundException.new("no project references the given repo url and commit branch") if projects.empty?

    projects
  end

  def all_jenkins_projects
    Java.jenkins.model.Jenkins.instance.getAllItems(AbstractProject.java_class).map { |jenkins_project| GitlabProject.new(jenkins_project) }
  end

  def get_commit_branch(payload)
    payload["ref"].gsub("refs/heads/", "") if payload && payload["ref"]
  end

  def is_delete_branch_commit?(payload)
    return false unless payload
    payload["after"].squeeze == "0" if payload && payload["after"]
  end

  def get_build_cause(repo_url, payload)
    repo_uri = URIish.new(repo_url)

    if payload
      notes = ["<br/>"]
      notes << "triggered by push on branch #{payload["ref"]}"
      notes << "with #{payload["total_commits_count"]} commit#{payload["total_commits_count"] == "1" ? "" : "s" }:"
      payload["commits"].each do |commit|
        notes << "* <a href=\"#{commit["url"]}\">#{commit["message"]}</a>"
      end
    else
      notes ["no payload available"]
    end

    Cause::RemoteCause.new(repo_uri.host, notes.join("<br/>"))
  end

  def create_project_for_branch(repo_url, branch, payload)
    copy_from = find_master_project(repo_url)

    safe_branch_name = branch.gsub("/", "_")
    new_project_name = "#{GitlabWebHook::USE_MASTER_PROJECT_NAME ? copy_from.name : payload["repository"]["name"]}_#{safe_branch_name}"

    # check if new project title already exists (this means that repo url and branch is not matched but the project name exists)
    all_jenkins_projects.each do |project|
      raise GitlabWebHook::ConfigurationException.new("project #{new_project_name} already exists but doesn't match the repo url #{repo_url} and #{branch} branch, can't create the new project") if project.name == new_project_name
    end

    # TODO: set github url, requires github plugin reference
    branch_project = Java.jenkins.model.Jenkins.instance.copy(copy_from.jenkins_project, new_project_name)
    branch_project.scm = prepare_scm_from(copy_from.scm, branch, payload)
    branch_project.makeDisabled(false)
    branch_project.description = GitlabWebHook::DESCRIPTION
    branch_project.save

    GitlabProject.new(branch_project)
  end

  def find_master_project(repo_url)
    repo_uri = URIish.new(repo_url)
    # find project for the repo and master branch
    master_project = all_jenkins_projects.find { |project| project.matches_repo_uri_and_branch?(repo_uri, GitlabWebHook::MASTER_BRANCH) }
    # use any other branch matching the repo
    unless master_project
      master_project = all_jenkins_projects.find { |project| project.matches_repo_uri_and_branch?(repo_uri, GitlabWebHook::ANY_BRANCH) }
    end

    raise GitlabWebHook::NotFoundException.new("could not determine master project, please create a project for the repo (usually for the master branch)") unless master_project
    raise GitlabWebHook::ConfigurationException.new("master project found: #{master_project}, but is not a Git type of project, can't proceed") unless master_project.is_git?

    master_project
  end

  def prepare_scm_from(source_scm, branch, payload)
    scm_name = source_scm.getScmName() && source_scm.getScmName().size > 0 ? "#{source_scm.getScmName()}_#{branch}" : nil

    # refspec is skipped, we will build specific commit branch
    remote_url, remote_name, remote_refspec = nil, nil, nil
    source_scm.getUserRemoteConfigs().first.tap do |config|
      remote_url = config.getUrl()
      remote_name = config.getName()
    end
    raise GitlabWebHook::ConfigurationException("remote repo clone url not found") unless remote_url

    remote_branch = remote_name && remote_name.size > 0 ? "#{remote_name}/#{branch}" : branch

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
      GitLab.new(payload["repository"]["homepage"]),
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

  def process_delete_commit(payload)
    commit_branch = get_commit_branch(payload)
    messages = []
    if GitlabWebHook::CREATE_PROJECTS_FOR_NON_MASTER_BRANCHES_AUTOMATICALLY && commit_branch != GitlabWebHook::MASTER_BRANCH
      all_jenkins_projects.each do |project|
        if project.is_exact_match?(commit_branch)
          messages << "project #{project} matches deleted branch but is not automatically created by the plugin, skipping" and next unless project.description.match /#{GitlabWebHook::DESCRIPTION}/
          project.delete
          messages << "deleted #{project} project"
        end
      end
      messages << "no project matches the #{commit_branch} branch" if messages.empty?
    else
      messages << "#{commit_branch} branch is deleted, but not configured for automatic branch projects creation, skipping processing"
    end
    messages
  end
end
