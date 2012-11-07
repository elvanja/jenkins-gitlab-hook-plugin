require 'forwardable'

include Java

java_import Java.hudson.model.ParametersDefinitionProperty
java_import Java.hudson.model.ParametersAction
java_import Java.hudson.model.StringParameterDefinition
java_import Java.hudson.model.StringParameterValue
java_import Java.hudson.plugins.git.GitSCM
java_import Java.hudson.plugins.git.util.InverseBuildChooser

java_import Java.java.util.logging.Logger

class GitlabProject
  extend Forwardable

  def_delegators :@jenkins_project, :scm, :schedulePolling, :scheduleBuild, :fullName, :isParameterized, :isBuildable, :getQuietPeriod, :getProperty, :getDefaultParametersValues

  alias_method :is_parametrized?, :isParameterized
  alias_method :is_buildable?, :isBuildable
  alias_method :name, :fullName
  alias_method :to_s, :fullName

  attr_reader :jenkins_project

  LOGGER = Logger.getLogger(GitlabProject.class.name)

  def initialize(jenkins_project)
    @jenkins_project = jenkins_project
  end

  def matches_repo_uri_and_branch?(repo_uri, branch)
    return false unless is_buildable?
    return false unless is_git?
    return false unless matches_repo_uri?(repo_uri)
    matches_branch?(branch).tap { |matches| LOGGER.info("project #{to_s} #{matches ? "matches": "doesn't match"} the #{branch} branch") }
  end

  def notify_commit
    return "#{to_s} is configured to ignore notify commit, skipping scheduling for polling" if is_ignoring_notify_commit?
    return "#{to_s} is not buildable (it is disabled or not saved), skipping polling" unless is_buildable?
    return "#{to_s} could not be scheduled for polling, it is disabled or has no SCM trigger" unless schedulePolling
    "#{to_s} scheduled for polling"
  end

  def build_now(cause, branch)
    return "#{to_s} is not buildable (it is disabled or not saved), skipping the build" unless is_buildable?
    return "#{to_s} could not be scheduled for build" unless scheduleBuild(getQuietPeriod(), cause, get_build_actions(branch))
    "#{to_s} scheduled for build"
  end

  def is_template?
    name == GitlabWebHook::TEMPLATE_PROJECT
  end

  def is_master?
    matches_branch?(GitlabWebHook::MASTER_BRANCH, true)
  end

  def is_exact_match?(branch)
    matches_branch?(branch, true)
  end

  def is_git?
    scm && scm.java_kind_of?(GitSCM)
  end

  private

  def is_ignoring_notify_commit?
    scm.isIgnoreNotifyCommit()
  end

  def matches_repo_uri?(repo_uri)
    scm.repositories.find do |repo|
      repo.getURIs().find { |project_repo_uri| repo_uris_match?(project_repo_uri, repo_uri) }
    end
  end

  def matches_branch?(branch, exact = false)
    matched_branch = scm.branches.find do |scm_branch|
      scm.repositories.find do |repo|
        token = "#{repo.name}/#{branch}"
        exact ? scm_branch.name == token : scm_branch.matches(token)
      end
    end

    matched_branch = get_branch_name_parameter if !matched_branch && is_parametrized?

    build_chooser = scm.buildChooser
    build_chooser && build_chooser.java_kind_of?(InverseBuildChooser) ? !matched_branch : matched_branch
  end

  def get_branch_name_parameter
    params = getProperty(ParametersDefinitionProperty.java_class).getParameterDefinitions()
    branch_name_param = params.find do |param|
      scm.branches.find do |scm_branch|
        scm.repositories.find do |repo|
          scm_branch.name.include?("${#{param.name}}")
        end
      end
    end

    raise GitlabWebHook::ConfigurationException.new("Only string parameters in branch specification are supported") if branch_name_param && !branch_name_param.java_kind_of?(StringParameterDefinition)
    branch_name_param
  end

  def get_build_actions(branch)
    # no need to process if not parameterized
    return unless is_parametrized?

    # no need to process if parameter list does not contain branch spec
    branch_parameter = get_branch_name_parameter
    return unless branch_parameter

    parameters_values = getDefaultParametersValues()
    parameters_values = parameters_values.reject { |value| value.name == branch_parameter.name }
    parameters_values << StringParameterValue.new(branch_parameter.name, branch)

    ParametersAction.new(parameters_values)
  end

  def repo_uris_match?(project_repo_uri, repo_uri)
    project_repo_uri.host == repo_uri.host && normalize_path(project_repo_uri.path) == normalize_path(repo_uri.path)
  end

  def normalize_path(path)
    path.slice!(0) if path.start_with?('/')
    path.slice!(-1) if path.end_with?('/')
    path.slice!(-4..-1) if path.end_with?('.git')
    path
  end
end
