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

  # TODO: bring this into the UI / project configuration
  # TODO: default params should be available, configuration overrides them
  # TODO: see build per branch project on how to find template project (regex)

  # TODO gitlab delete hook should be covered
  #   project for the branch should be deleted
  #   a hook to delete artifacts from the feature branches would be nice

  # TODO: automatic separating of branches into separate jenkins projects
  CREATE_PROJECTS_FOR_NON_MASTER_BRANCHES_AUTOMATICALLY = true
  MASTER_BRANCH = "master"
  ANY_BRANCH = "**"
  TEMPLATE_PROJECT = "template"
  NEW_PROJET_NAME = "${REPO_NAME}_${BRANCH_NAME}"
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
      messages << "branch is deleted, nothing to build"
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

    # TODO: instead of checking master branch, see if it is parametrized and then decide on what to do
    if GitlabWebHook::CREATE_PROJECTS_FOR_NON_MASTER_BRANCHES_AUTOMATICALLY && commit_branch != GitlabWebHook::MASTER_BRANCH
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
    # TODO: allow for branches like feature/some_new_feature or any depth from refs/heads
    payload["ref"].split("/").last if payload && payload["ref"]
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
    copy_from = find_template_project(repo_url)

    safe_branch_name = branch.gsub("/", "_")
    new_project_name = "#{copy_from.is_template? ? payload["repository"]["name"] : copy_from.name}_#{safe_branch_name}"

    # TODO: check if new project title already exists (this means that repo url is not matched but the project name exists) !!!
    branch_job = Java.jenkins.model.Jenkins.instance.copy(copy_from.jenkins_project, new_project_name)
    # TODO: set github url, requires github plugin reference
    # TODO: remove branch parameter if exists, leave other params, maybe not needed because default will be used !!! branch_job.removeProperty(ParametersDefinitionProperty.java_class) if (branch_job.isParameterized)
    branch_job.scm = prepare_scm_from_template(copy_from.scm, repo_url, branch, payload)
    branch_job.makeDisabled(false)
    branch_job.save

    GitlabProject.new(branch_job)
  end

  def find_template_project(repo_url)
    # use template project if configured
    template_project = all_jenkins_projects.find { |project| project.is_template? }
    raise GitlabWebHook::ConfigurationException.new("the configured template project #{GitlabWebHook::TEMPLATE_PROJECT} does not exist, can't proceed") if GitlabWebHook::TEMPLATE_PROJECT && !template_project

    # find project for the repo and master branch
    repo_uri = URIish.new(repo_url)
    unless template_project
      template_project = all_jenkins_projects.find { |project| project.matches_repo_uri_and_branch?(repo_uri, GitlabWebHook::MASTER_BRANCH) }
    end

    # use any other branch matching the repo
    unless template_project
      template_project = all_jenkins_projects.find { |project| project.matches_repo_uri_and_branch?(repo_uri, GitlabWebHook::ANY_BRANCH) }
    end

    raise GitlabWebHook::NotFoundException.new("could not determine template project, please configure one or manually create a project for the repo (usually for the master branch)") unless template_project
    raise GitlabWebHook::ConfigurationException.new("template project found: #{template_project}, but is not a Git type of project, can't proceed") unless template_project.is_git?

    template_project
  end

  def prepare_scm_from_template(template_scm, repo_url, branch, payload)
    scm_name = template_scm.getScmName() && template_scm.getScmName().size > 0 ? "#{template_scm.getScmName()}_#{branch}" : nil
    remote_name = nil
    template_scm.getUserRemoteConfigs().first.tap do |config|
      remote_name = config.getName()
    end
    remote_branch = remote_name ? "#{remote_name}/#{branch}" : branch

    GitSCM.new(
      scm_name,
      [UserRemoteConfig.new(repo_url, remote_name, nil)],
      [BranchSpec.new(remote_branch)],
      template_scm.getUserMergeOptions(),
      template_scm.getDoGenerate(),
      template_scm.getSubmoduleCfg(),
      template_scm.getClean(),
      template_scm.getWipeOutWorkspace(),
      DefaultBuildChooser.new,
      GitLab.new(payload["repository"]["homepage"]),
      template_scm.getGitTool,
      template_scm.getAuthorOrCommitter(),
      template_scm.getRelativeTargetDir(),
      template_scm.getReference(),
      template_scm.getExcludedRegions(),
      template_scm.getExcludedUsers(),
      template_scm.getLocalBranch(),
      template_scm.getDisableSubmodules(),
      template_scm.getRecursiveSubmodules(),
      template_scm.getPruneBranches(),
      template_scm.getRemotePoll(),
      template_scm.getGitConfigName(),
      template_scm.getGitConfigEmail(),
      template_scm.getSkipTag(),
      template_scm.getIncludedRegions(),
      template_scm.isIgnoreNotifyCommit(),
      template_scm.getUseShallowClone()
    )
  end
end
