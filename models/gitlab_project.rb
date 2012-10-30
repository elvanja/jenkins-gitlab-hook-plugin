require 'forwardable'

class GitlabProject
  extend Forwardable

  def_delegators :@jenkins_project, :scm, :schedulePolling, :scheduleBuild, :fullName

  def initialize(jenkins_project)
    @jenkins_project = jenkins_project
  end

  def matches_repo_uri_and_branch?(repo_uri, branch)
    return false unless is_git?
    return false unless matches_repo_uri?(repo_uri)
    matches_branch?(branch)
  end

  def is_template?
    fullName.include?(TEMPLATE_PROJECT_TAG)
  end

  def is_master?
    matches_branch?(MASTER_BRANCH, true)
  end

  def is_exact_match?(branch)
    matches_branch?(branch, true)
  end

  def is_ignoring_notify_commit?
    scm.isIgnoreNotifyCommit()
  end

  def to_s
    fullName
  end

  private

  def is_git?
    scm && scm.java_kind_of?(GitSCM)
  end

  def matches_repo_uri?(given_repo_uri)
    scm.repositories.find do |repo|
      repo.getURIs().find { |project_repo_uri| repo_uris_match?(project_repo_uri, given_repo_uri) }
    end
  end

  def matches_branch?(given_branch, exact = false)
    matched_branch = scm.branches.find do |scm_branch|
      scm.repositories.find do |repo|
        token = "#{repo.name}/#{given_branch}"
        exact ? scm_branch.name == token : scm_branch.matches(token)
      end
    end
    return matched_branch if exact

    build_chooser = scm.buildChooser
    build_chooser && build_chooser.java_kind_of?(InverseBuildChooser) ? !matched_branch : matched_branch
  end

  def repo_uris_match?(project_repo_uri, given_repo_uri)
    project_repo_uri.host == given_repo_uri.host && normalize_path(project_repo_uri.path) == normalize_path(given_repo_uri.path)
  end

  def normalize_path(path)
    path.slice!(0) if path.start_with?('/')
    path.slice!(-1) if path.end_with?('/')
    path.slice!(-4..-1) if path.end_with?('.git')
    path
  end
end
