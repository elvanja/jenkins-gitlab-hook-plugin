require 'sinatra/base'

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

class GitlabWebHookApi < Sinatra::Base
  LOGGER = Logger.getLogger(GitlabWebHookApi.class.name)

  get '/ping' do
    'Gitlab Web Hook is up and running :-)'
  end

  notify_commit = lambda do
    process_projects do |project|
      next "#{project.fullName} is configured to ignore notify commit, skipping scheduling for polling" if is_ignoring_notify_commit?(project)
      next "#{project.fullName} could not be scheduled for polling, it is disabled or has no SCM trigger" unless project.schedulePolling()
      "#{project.fullName} scheduled for polling"
    end
  end

  get '/notify_commit', &notify_commit
  post '/notify_commit', &notify_commit

  build_now = lambda do
    process_projects do |project, repo_url, payload|
      cause = prepare_build_cause(repo_url, payload)
      next "#{project.fullName} could not be scheduled for build, it is disabled or not saved" unless project.scheduleBuild(cause)
      "#{project.fullName} scheduled for build"
    end
  end

  get '/build_now', &build_now
  post '/build_now', &build_now

private

  class BadRequestException < Exception
  end

  class NotFoundException < Exception
  end

  def process_projects
    begin
      # set system priviledges to be able to see all projects
      # see https://wiki.jenkins-ci.org/display/JENKINS/Git+Plugin hudson.plugins.git.GitStatus#doNotifyCommit comments for details
      old_authentication_level = SecurityContextHolder.getContext().getAuthentication()
      SecurityContextHolder.getContext().setAuthentication(ACL::SYSTEM)

      repo_url, payload = get_repo_url_from_params
      LOGGER.info("gitlab web hook triggered for repo url #{repo_url}")
      messages = []
      get_projects_for_repo_url_and_commit_branch(repo_url, payload["ref"]).each do |project|
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

    begin
      request.body.rewind
      payload = JSON.parse(request.body.read)
      repo_url = payload["repository"]["url"]
    rescue
    end
    raise BadRequestException.new("repo url not found in Gitlab payload or the Get parameters #{[params.inspect, request.body.read].join(",")}") unless repo_url && !repo_url.empty?

    return repo_url, payload
  end

  def get_projects_for_repo_url_and_commit_branch(repo_url, ref)
    payload_repo_uri = URIish.new(repo_url)
    commit_branch = ref.split("/").last

    projects = Java.jenkins.model.Jenkins.instance.getAllItems(AbstractProject.java_class).select do |project|
      scm = project.scm
      next unless scm_is_git?(scm)
      next unless scm_repo_urls_match_payload_repo_url?(scm, payload_repo_uri)
      scm_branches_match_commit_branch?(scm, commit_branch)
    end
    raise NotFoundException.new("no project references the given repo url and commit branch") if projects.empty?

    projects
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

  def is_ignoring_notify_commit?(project)
    project.scm.isIgnoreNotifyCommit()
  end

  def scm_is_git?(scm)
    scm && scm.java_kind_of?(GitSCM)
  end

  def scm_repo_urls_match_payload_repo_url?(scm, payload_repo_uri)
    scm.repositories.find do |repo|
      repo.getURIs().find { |uri| repo_urls_match?(uri, payload_repo_uri) }
    end
  end

  def scm_branches_match_commit_branch?(scm, commit_branch)
    matched_branch = scm.branches.find do |scm_branch|
      scm.repositories.find do |repo|
        scm_branch.matches("#{repo.name}/#{commit_branch}")
      end
    end
    build_chooser = scm.buildChooser

    build_chooser && build_chooser.java_kind_of?(InverseBuildChooser) ? !matched_branch : matched_branch
  end

  def repo_urls_match?(first, second)
    first.host == second.host && normalize_path(first.path) == normalize_path(second.path)
  end

  def normalize_path(path)
    path.slice!(0) if path.start_with?('/')
    path.slice!(-1) if path.end_with?('/')
    path.slice!(-4..-1) if path.end_with?('.git')
    path
  end
end
