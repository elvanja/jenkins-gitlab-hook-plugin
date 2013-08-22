require 'forwardable'

require_relative '../exceptions/configuration_exception'

include Java

java_import Java.hudson.model.ParametersDefinitionProperty
java_import Java.hudson.model.StringParameterDefinition
java_import Java.hudson.plugins.git.GitSCM
java_import Java.hudson.plugins.git.util.InverseBuildChooser

java_import Java.org.eclipse.jgit.transport.URIish

java_import Java.java.util.logging.Logger
java_import Java.java.util.logging.Level

module GitlabWebHook
  class Project
    extend Forwardable

    def_delegators :@jenkins_project, :scm, :schedulePolling, :scheduleBuild2, :fullName, :isParameterized, :isBuildable, :getQuietPeriod, :getProperty, :delete, :description

    alias_method :is_parametrized?, :isParameterized
    alias_method :is_buildable?, :isBuildable
    alias_method :name, :fullName
    alias_method :to_s, :fullName

    attr_reader :jenkins_project

    LOGGER = Logger.getLogger(Project.class.name)

    def initialize(jenkins_project)
      @jenkins_project = jenkins_project
    end

    def matches?(repository_url, branch, exactly = false)
      return false unless is_buildable?
      return false unless matches_repo_uri?(repository_url)
      matches_branch?(branch, exactly).tap { |matches| LOGGER.info("project #{self} #{matches ? "matches": "doesn't match"} the #{branch} branch") }
    end

    def is_ignoring_notify_commit?
      scm.isIgnoreNotifyCommit()
    end

    def get_branch_name_parameter
      if scm.repositories.size > 0
        branch_name_param = get_default_parameters.find do |param|
          scm.branches.find do |scm_branch|
            scm_branch.name.match(/.*\$\{?#{param.name}\}?.*/)
          end
        end
      end

      raise ConfigurationException.new("Only string parameters in branch specification are supported") if branch_name_param && !branch_name_param.java_kind_of?(StringParameterDefinition)
      branch_name_param
    end

    def get_default_parameters
      # @see hudson.model.AbstractProject#getDefaultParametersValues
      getProperty(ParametersDefinitionProperty.java_class).getParameterDefinitions()
    end

    private

    def matches_repo_uri?(repository_url)
      return false unless is_git?

      repo_uri = URIish.new(repository_url)

      scm.repositories.find do |repo|
        repo.getURIs().find { |project_repo_uri| repo_uris_match?(project_repo_uri, repo_uri) }
      end
    end

    def matches_branch?(branch, exactly = false)
      return false unless is_git?

      matched_branch = scm.branches.find do |scm_branch|
        scm.repositories.find do |repo|
          token = "#{repo.name}/#{branch}"
          exactly ? scm_branch.name == token : scm_branch.matches(token)
        end
      end

      matched_branch = get_branch_name_parameter if !matched_branch && is_parametrized?

      build_chooser = scm.buildChooser
      build_chooser && build_chooser.java_kind_of?(InverseBuildChooser) ? !matched_branch : matched_branch
    end

    def is_git?
      scm && scm.java_kind_of?(GitSCM)
    end

    def repo_uris_match?(project_repo_uri, repo_uri)
      project_repo_host = project_repo_uri ? project_repo_uri.host.downcase : nil
      project_repo_path = project_repo_uri ? normalize_path(project_repo_uri.path).downcase : nil

      repo_uri_host = repo_uri ? repo_uri.host.downcase : nil
      repo_uri_path = repo_uri ? normalize_path(repo_uri.path).downcase : nil

      project_repo_host == repo_uri_host && project_repo_path == repo_uri_path
    end

    def normalize_path(path)
      path.slice!(0) if path.start_with?('/')
      path.slice!(-1) if path.end_with?('/')
      path.slice!(-4..-1) if path.end_with?('.git')
      path
    end
  end
end
