require 'sinatra/base'

require_relative 'gitlab_project'

include Java

java_import Java.hudson.model.Cause
java_import Java.hudson.model.AbstractProject
java_import Java.hudson.security.ACL

java_import Java.org.eclipse.jgit.transport.URIish
java_import Java.org.acegisecurity.Authentication
java_import Java.org.acegisecurity.context.SecurityContextHolder

java_import Java.java.util.logging.Logger

module GitlabWebHook
  class ConfigurationException < Exception; end
  class BadRequestException < Exception; end
  class NotFoundException < Exception; end
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
    raise GitlabWebHook::NotFoundException.new("no project references the given repo url and commit branch") if projects.empty?

    projects
  end

  def all_jenkins_projects
    Java.jenkins.model.Jenkins.instance.getAllItems(AbstractProject.java_class).map { |jenkins_project| GitlabProject.new(jenkins_project) }
  end

  def get_commit_branch(payload)
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
end
