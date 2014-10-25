require_relative '../services/get_jenkins_projects'

module GitlabWebHook
  class ProcessDeleteCommit
    def initialize(get_jenkins_projects = GetJenkinsProjects.new)
      @get_jenkins_projects = get_jenkins_projects
    end

    def with(details)
      settings = Java.jenkins.model.Jenkins.instance.descriptor GitlabWebHookRootActionDescriptor.java_class
      commit_branch = details.branch

      return ["branch #{commit_branch} is deleted, but automatic branch projects creation is not active, skipping processing"] unless settings.automatic_project_creation?
      return ["branch #{commit_branch} is deleted, but relates to master project so will not delete, skipping processing"] if commit_branch == settings.master_branch

      messages = []
      @get_jenkins_projects.matching_uri(details).select do |project|
        project.matches?(details.repository_uri, details.branch, true)
      end.each do |project|
        messages << "project #{project} matches deleted branch but is not automatically created by the plugin, skipping" and next unless project.description.match /#{settings.description}/
        project.delete
        messages << "deleted #{project} project"
      end
      messages << "no project matches the #{commit_branch} branch" if messages.empty?

      messages
    end
  end
end
