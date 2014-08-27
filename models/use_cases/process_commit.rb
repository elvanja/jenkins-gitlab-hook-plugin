require_relative 'create_project_for_branch'
require_relative '../values/settings'
require_relative '../services/get_jenkins_projects'

module GitlabWebHook
  class ProcessCommit
    def initialize(get_jenkins_projects = GetJenkinsProjects.new, create_project_for_branch = CreateProjectForBranch.new)
      @get_jenkins_projects = get_jenkins_projects
      @create_project_for_branch = create_project_for_branch
    end

    LOGGER = Logger.getLogger(ProcessCommit.class.name)

    def with(details, action)
      projects = get_projects_to_process(details)

      messages = []
      projects.each do |project|
        messages << action.call(project, details)
      end
      messages
    end

    private

    def get_projects_to_process(details)
      projects = []
      if Settings.automatic_project_creation?
        projects.concat( @get_jenkins_projects.exactly_matching(details) )
        begin
          projects << @create_project_for_branch.with(details) if projects.empty?
        rescue Exception => e
          LOGGER.warning( "Exception on create_project_for_branch : #{e.message}" )
        end
      end
      projects.concat( @get_jenkins_projects.matching(details) ) if projects.empty?
      raise NotFoundException.new('no project references the given repo url and commit branch') if projects.empty?

      projects.flatten
    end
  end
end
