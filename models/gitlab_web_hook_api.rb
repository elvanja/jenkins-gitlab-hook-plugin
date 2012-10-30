require 'sinatra/base'

require_relative 'gitlab_project'

include Java

java_import Java.hudson.model.AbstractProject
java_import Java.hudson.model.Cause
java_import Java.hudson.plugins.git.GitSCM
java_import Java.hudson.plugins.git.util.InverseBuildChooser
java_import Java.org.eclipse.jgit.transport.URIish
java_import Java.java.util.logging.Logger

java_import Java.org.acegisecurity.Authentication
java_import Java.org.acegisecurity.context.SecurityContextHolder
java_import Java.hudson.security.ACL

# TODO: bring this into the UI / project configuration
SEPARATE_PROJECTS_FOR_NON_MASTER_BRANCHES = false
MASTER_BRANCH = "master"
TEMPLATE_PROJECT_TAG = "template"
NEW_PROJET_NAME = '#{REPO_NAME}_#{BRANCH_NAME}'

class GitlabWebHookApi < Sinatra::Base
  LOGGER = Logger.getLogger(GitlabWebHookApi.class.name)

  get '/ping' do
    'Gitlab Web Hook is up and running :-)'
  end

  notify_commit = lambda do
    get_projects_to_process do |project|
      next "#{project} is configured to ignore notify commit, skipping scheduling for polling" if project.is_ignoring_notify_commit?
      next "#{project} could not be scheduled for polling, it is disabled or has no SCM trigger" unless project.schedulePolling()
      "#{project} scheduled for polling"
    end
  end
  get '/notify_commit', &notify_commit
  post '/notify_commit', &notify_commit

  build_now = lambda do
    get_projects_to_process do |project, repo_url, payload|
      cause = prepare_build_cause(repo_url, payload)
      next "#{project} could not be scheduled for build, it is disabled or not saved" unless project.scheduleBuild(cause)
      "#{project} scheduled for build"
    end
  end
  get '/build_now', &build_now
  post '/build_now', &build_now

  private

  class BadRequestException < Exception
  end

  class NotFoundException < Exception
  end

  def get_projects_to_process
    begin
      # set system priviledges to be able to see all projects
      # see https://wiki.jenkins-ci.org/display/JENKINS/Git+Plugin hudson.plugins.git.GitStatus#doNotifyCommit comments for details
      old_authentication_level = SecurityContextHolder.getContext().getAuthentication()
      SecurityContextHolder.getContext().setAuthentication(ACL::SYSTEM)

      repo_url, payload = get_repo_url_from_params
      LOGGER.info("gitlab web hook triggered for repo url #{repo_url}")
      messages = []
      get_projects_for_repo_url_and_commit_branch(repo_url, payload).each do |project|
        messages << yield(project, repo_url, payload)
      end
      LOGGER.info(messages.join("\n"))
      messages.join("<br/>")
    rescue BadRequestException => e
      LOGGER.warning(e.message)
      status 400
      e.message
    rescue NotFoundException => e
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
    raise BadRequestException.new("repo url not found in Gitlab payload or the Get parameters #{[params.inspect, request.body.read].join(",")}") unless repo_url && !repo_url.empty?

    return repo_url, payload
  end

  def get_projects_for_repo_url_and_commit_branch(repo_url, payload)
    payload_repo_uri = URIish.new(repo_url)
    commit_branch = payload["ref"].split("/").last if payload && payload["ref"]

    projects = all_jenkins_projects.select do |project|
      project.matches_repo_uri_and_branch?(payload_repo_uri, commit_branch)
    end

    if SEPARATE_PROJECTS_FOR_NON_MASTER_BRANCHES && commit_branch != MASTER_BRANCH
      LOGGER.info("separating branches !!!")
      projects.select! { |project| project.is_exact_match?(commit_branch) }
      #projects << create_project_for_branch(repo_url, commit_branch) if projects.empty?
    end

    raise NotFoundException.new("no project references the given repo url #{repo_url} and commit branch #{commit_branch}") if projects.empty?

    projects
  end

  def all_jenkins_projects
    Java.jenkins.model.Jenkins.instance.getAllItems(AbstractProject.java_class).map { |jenkins_project| GitlabProject.new(jenkins_project) }
  end

  def prepare_build_cause(repo_url, payload)
    begin
      repo_uri = URIish.new(repo_url)
    rescue Exception => e
      raise BadRequestException.new("illegal repo url #{repo_url} #{e.message}") if projects.empty?
    end

    notes = []
    if payload
      notes << "<br/>"
      notes << "triggered by push on branch #{payload["ref"]}"
      notes << "with #{payload["total_commits_count"]} commit#{payload["total_commits_count"] == "1" ? "" : "s" }:"
      payload["commits"].each do |commit|
        notes << "* <a href=\"#{commit["url"]}\">#{commit["message"]}</a>"
      end
    else
      notes << "no payload available"
    end

    Cause::RemoteCause.new(repo_uri.host, notes.join("<br/>"))
  end

  def create_project_for_branch(commit_branch)
    template_project = all_jenkins_projects.find { |project| project.is_template? }
    raise NotFoundException.new("missing template project to use for #{commit_branch} branch on #{repo_url} project") unless template_project

    # TODO: create a copy of the template project and save it
  end
end
