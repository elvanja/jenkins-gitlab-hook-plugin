require_relative 'create_project_for_branch'
require_relative '../services/get_jenkins_projects'
require_relative '../util/settings'

module GitlabWebHook
  class ProcessCommit
    include Settings

    def initialize(get_jenkins_projects = GetJenkinsProjects.new, create_project_for_branch = CreateProjectForBranch.new)
      @get_jenkins_projects = get_jenkins_projects
      @create_project_for_branch = create_project_for_branch
    end

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
      projects = @get_jenkins_projects.matching_uri(details)
      if projects.any?
        if settings.automatic_project_creation?
          projects.select! do |project|
            project.matches?(details, details.branch, true)
          end
          projects << @create_project_for_branch.with(details) if projects.empty?
        else
          projects.select! do |project|
            project.matches?(details)
          end
        end
      else
        settings.templated_jobs.each do |matchstr,template|
          if details.repository_name.start_with? matchstr
            projects << @create_project_for_branch.from_template(template, details)
          end
        end
        return projects if projects.any?
        settings.templated_groups.each do |matchstr,template|
          if details.repository_group == matchstr
            projects << @create_project_for_branch.from_template(template, details)
          end
        end
        return projects if projects.any?
        if settings.template_fallback
          projects << @create_project_for_branch.from_template(settings.template_fallback, details)
        end
      end

      raise NotFoundException.new('no project references the given repo url and commit branch') unless projects.any?

      projects
    end
  end
end
