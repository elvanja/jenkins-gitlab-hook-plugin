require_relative '../services/get_jenkins_projects'
require_relative '../services/get_build_cause'
require_relative '../services/get_build_actions'

module GitlabWebHook
  class BuildNow
    attr_reader :project, :logger

    java_import Java.java.util.logging.Logger
    java_import Java.java.util.logging.Level

    def initialize(project, logger = Logger.getLogger(self.class.name))
      raise ArgumentError.new('project is required') unless project
      @project = project
      @logger = logger
    end

    def with(details, cause_builder = GetBuildCause.new, actions_builder = GetBuildActions.new)
      return "#{project} is configured to ignore notify commit, skipping the build" if project.ignore_notify_commit?
      return "#{project} is not buildable (it is disabled or not saved), skipping the build" unless project.buildable?
      raise ArgumentError.new('details are required') unless details

      begin
        return "#{project} scheduled for build" if project.scheduleBuild2(project.getQuietPeriod(), cause_builder.with(details), actions_builder.with(project, details))
      rescue java.lang.Exception => e
        # avoid method signature warnings
        severe = logger.java_method(:log, [Level, java.lang.String, java.lang.Throwable])
        severe.call(Level::SEVERE, e.message, e)
      end

      "#{project} could not be scheduled for build"
    end
  end
end
