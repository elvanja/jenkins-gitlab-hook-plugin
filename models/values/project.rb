require 'forwardable'

require_relative '../exceptions/configuration_exception'

include Java

java_import Java.hudson.model.ParametersDefinitionProperty
java_import Java.hudson.model.StringParameterDefinition
java_import Java.hudson.plugins.git.GitSCM
java_import Java.hudson.plugins.git.util.InverseBuildChooser

java_import Java.java.util.logging.Logger
java_import Java.java.util.logging.Level

module GitlabWebHook
  class Project
    extend Forwardable

    def_delegators :@jenkins_project, :scm, :schedulePolling, :scheduleBuild2, :fullName, :isParameterized, :isBuildable, :getQuietPeriod, :getProperty, :delete, :description

    alias_method :parametrized?, :isParameterized
    alias_method :buildable?, :isBuildable
    alias_method :name, :fullName
    alias_method :to_s, :fullName

    attr_reader :jenkins_project

    LOGGER = Logger.getLogger(Project.class.name)

    def initialize(jenkins_project, logger = nil)
      raise ArgumentError.new("jenkins project is required") unless jenkins_project
      @jenkins_project = jenkins_project
      @logger = logger
    end

    def matches?(details_uri, branch, exactly = false)
      return false unless buildable?
      return false unless git?
      return false unless matches_repo_uri?(details_uri)
      matches_branch?(branch, exactly).tap { |matches| logger.info("project #{self} #{matches ? "matches": "doesn't match"} the #{branch} branch") }
    end

    def ignore_notify_commit?
      scm.isIgnoreNotifyCommit()
    end

    def get_branch_name_parameter
      if scm.repositories.size > 0
        branch_name_param = get_default_parameters.find do |param|
          scm.branches.find do |scm_branch|
            scm_branch.name.match(/.*\$?\{?#{param.name}\}?.*/)
          end
        end
      end

      raise ConfigurationException.new("only string parameters for branch parameter are supported") if branch_name_param && !branch_name_param.java_kind_of?(StringParameterDefinition)
      branch_name_param
    end

    def get_default_parameters
      # @see jenkins.model.ParameterizedJobMixIn.getDefaultParametersValues used in hudson.model.AbstractProject
      getProperty(ParametersDefinitionProperty.java_class).getParameterDefinitions()
    end

    private

    def matches_repo_uri?(details_uri)
      scm.repositories.find do |repo|
        repo.getURIs().find { |project_repo_uri| details_uri.matches?(project_repo_uri) }
      end
    end

    def matches_branch?(branch, exactly = false)
      matched_branch = scm.branches.find do |scm_branch|
        scm.repositories.find do |repo|
          token = "#{repo.name}/#{branch}"
          exactly ? scm_branch.name == token : scm_branch.matches(token)
        end
      end

      matched_branch = get_branch_name_parameter if !matched_branch && parametrized?

      build_chooser = scm.buildChooser
      build_chooser && build_chooser.java_kind_of?(InverseBuildChooser) ? !matched_branch : matched_branch
    end

    def git?
      scm && scm.java_kind_of?(GitSCM)
    end

    def logger
      @logger || LOGGER
    end
  end
end
