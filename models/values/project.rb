require 'forwardable'

require_relative '../exceptions/configuration_exception'

include Java

java_import Java.hudson.model.ParametersDefinitionProperty
java_import Java.hudson.model.StringParameterDefinition
java_import Java.hudson.model.ChoiceParameterDefinition
java_import Java.hudson.util.StreamTaskListener
java_import Java.hudson.util.NullStream
java_import Java.hudson.plugins.git.GitSCM
java_import Java.hudson.plugins.git.util.InverseBuildChooser

java_import Java.java.util.logging.Logger

MultipleScmsPluginAvailable = true
begin
  java_import Java.org.jenkinsci.plugins.multiplescms.MultiSCM
rescue NameError
  MultipleScmsPluginAvailable = false
end

module GitlabWebHook
  class Project
    BRANCH_NAME_PARAMETER_ACCEPTED_TYPES = [StringParameterDefinition, ChoiceParameterDefinition]

    extend Forwardable

    def_delegators :@jenkins_project, :scm, :schedulePolling, :scheduleBuild2, :fullName, :isParameterized, :isBuildable, :getQuietPeriod, :getProperty, :delete, :description

    alias_method :parametrized?, :isParameterized
    alias_method :buildable?, :isBuildable
    alias_method :name, :fullName
    alias_method :to_s, :fullName

    attr_reader :jenkins_project, :scms, :logger
    attr_reader :matching_scms

    def initialize(jenkins_project, logger = Logger.getLogger(Project.class.name))
      raise ArgumentError.new("jenkins project is required") unless jenkins_project
      @jenkins_project = jenkins_project
      @logger = logger
      setup_scms
    end

    def matches_uri?(details_uri)
      return false unless (git? || multi_scm?)
      matching_scms?(details_uri)
    end

    def matches?(details, branch = false, exactly = false)
      return false unless buildable?
      return false unless matches_uri?(details.repository_uri)
      matches_branch?(branch || details.branch, details.full_branch_reference, exactly)
    end

    def ignore_notify_commit?
      scms.find { |scm| scm.isIgnoreNotifyCommit() }
    end

    def get_branch_name_parameter
      branch_name_param = get_default_parameters.find do |param|
        scms.find do |scm|
          next unless scm.repositories.size > 0
          scm.branches.find do |scm_branch|
            scm_branch.name.match(/.*\$?\{?#{param.name}\}?.*/)
          end
        end
      end

      if branch_name_param && !BRANCH_NAME_PARAMETER_ACCEPTED_TYPES.any? { |type| branch_name_param.java_kind_of?(type) }
        logger.warning("only string and choice parameters for branch parameter are supported")
        return nil
      end

      branch_name_param
    end

    def get_default_parameters
      # @see jenkins.model.ParameterizedJobMixIn.getDefaultParametersValues used in hudson.model.AbstractProject
      getProperty(ParametersDefinitionProperty.java_class).getParameterDefinitions()
    end

    private

    def matching_scms?(details_uri)
      matching_scms(details_uri).any?
    end

    def matching_scms(details_uri)
      @matching_scms ||= scms.select do |scm|
        scm.repositories.find do |repo|
          repo.getURIs().find do |project_repo_uri|
            details_uri.matches?(project_repo_uri)
          end
        end
      end
    end

    def matches_branch?(branch, refspec, exactly = false)
      matched_refspecs = []
      matched_branch = nil

      matched_scm = @matching_scms.find do |scm|
        matched_branch = scm.branches.find do |scm_branch|
          scm.repositories.find do |repo|
            token = "#{repo.name}/#{branch}"
            scm_refspecs = repo.getFetchRefSpecs().select { |scm_refspec| scm_refspec.matchSource(refspec) }
            matched_refspecs.concat(scm_refspecs)
            scm_refspecs.any? && (exactly ? scm_branch.name == token : scm_branch.matches(token))
          end
        end
      end

      matched_branch = get_branch_name_parameter if !matched_branch && matched_refspecs.any? && parametrized?

      matched_scm = @matching_scms.find { |scm| scm.buildChooser.java_kind_of?(InverseBuildChooser) } unless matched_scm
      build_chooser = matched_scm.buildChooser if matched_scm
      build_chooser && build_chooser.java_kind_of?(InverseBuildChooser) ? matched_branch.nil? : !matched_branch.nil?
    end

    def git?
      scm && scm.java_kind_of?(GitSCM)
    end

    def multi_scm?
      scm && MultipleScmsPluginAvailable && scm.java_kind_of?(MultiSCM)
    end

    def setup_scms
      @scms = []
      if git?
        @scms << scm
      elsif multi_scm?
        @scms.concat(scm.getConfiguredSCMs().select { |scm| scm.java_kind_of?(GitSCM) })
      end
    end
  end
end
