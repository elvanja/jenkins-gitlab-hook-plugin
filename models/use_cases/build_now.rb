require_relative '../values/settings'
require_relative '../services/get_jenkins_projects'
require_relative '../services/get_build_cause'
require_relative '../services/get_build_actions'

module GitlabWebHook
  class BuildNow
    LOGGER = Logger.getLogger(BuildNow.class.name)

    attr_reader :project

    def initialize(project)
      @project = project
    end

    def with(details)
      return "#{project} is configured to ignore notify commit, skipping the build" if project.is_ignoring_notify_commit?
      return "#{project} is not buildable (it is disabled or not saved), skipping the build" unless project.is_buildable?

      begin
        return "#{project} scheduled for build" if project.scheduleBuild2(project.getQuietPeriod(), GetBuildCause.new.with(details), GetBuildActions.new.with(project, details))
      rescue Exception => e
        LOGGER.log(Level::SEVERE, e.message, e)
      end

      "#{project} could not be scheduled for build"
    end
  end
end