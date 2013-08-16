require_relative 'create_project_for_branch'
require_relative '../values/settings'
require_relative '../services/get_jenkins_projects'

module GitlabWebHook
  class ProcessCommit
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
      if Settings.automatic_project_creation?
        projects = GetJenkinsProjects.new.exactly_matching(details)
        projects << CreateProjectForBranch.new.with(details) if projects.empty?
      else
        projects = GetJenkinsProjects.new.matching(details)
      end

      raise NotFoundException.new("no project references the given repo url and commit branch") if projects.empty?

      projects
    end
  end
end