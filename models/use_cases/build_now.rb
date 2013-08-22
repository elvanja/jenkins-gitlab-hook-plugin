require_relative '../values/settings'
require_relative '../services/get_jenkins_projects'
require_relative '../services/get_build_cause'
require_relative '../services/get_build_actions'

module GitlabWebHook
  class BuildNow
    LOGGER = Logger.getLogger(self.class.name)

    attr_reader :project

    def initialize(project, logger = nil)
      raise ArgumentError.new("project is required") unless project
      @project = project
      @logger = logger
    end

    def with(details, cause_builder = GetBuildCause.new, actions_builder = GetBuildActions.new)
      return "#{project} is configured to ignore notify commit, skipping the build" if project.is_ignoring_notify_commit?
      return "#{project} is not buildable (it is disabled or not saved), skipping the build" unless project.is_buildable?
      validate(details)

      begin
        return "#{project} scheduled for build" if project.scheduleBuild2(project.getQuietPeriod(), cause_builder.with(details), actions_builder.with(project, details))
      rescue Exception => e
        logger.log(Level::SEVERE, e.message, e)
      end

      "#{project} could not be scheduled for build"
    end

    private

    def validate(details)
      raise ArgumentError.new("details are required") unless details
    end

    def logger
      @logger || LOGGER
    end
  end
end