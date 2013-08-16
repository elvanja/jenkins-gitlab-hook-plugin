require_relative '../values/settings'
require_relative '../services/get_jenkins_projects'

module GitlabWebHook
  class ProcessDeleteCommit
    def with(details)
      commit_branch = details.branch

      return ["branch #{commit_branch} is deleted, but automatic branch projects creation is not active, skipping processing"] unless Settings.automatic_project_creation?
      return ["branch #{commit_branch} is deleted, but relates to master project so will not delete, skipping processing"] if commit_branch == Settings.master_branch

      messages = []
      GetJenkinsProjects.new.exactly_matching(details).each do |project|
        messages << "project #{project} matches deleted branch but is not automatically created by the plugin, skipping" and next unless project.description.match /#{Settings.description}/
        project.delete
        messages << "deleted #{project} project"
      end
      messages << "no project matches the #{commit_branch} branch" if messages.empty?

      messages
    end
  end
end