require_relative '../settings'
require_relative '../services/get_jenkins_projects'

module GitlabWebHook
  class ProcessDeleteCommit
    def with(details)
      commit_branch = details.branch

      messages = []
      if Settings.automatic_project_creation? && commit_branch != Settings.master_branch
        # TODO this should probably match repository_url as well
        GetJenkinsProjects.new.all.each do |project|
          #TODO move this to GetJenkinsProjects use case !!!
          if project.is_exact_match?(commit_branch)
            messages << "project #{project} matches deleted branch but is not automatically created by the plugin, skipping" and next unless project.description.match /#{Settings.description}/
            project.delete
            messages << "deleted #{project} project"
          end
        end
        messages << "no project matches the #{commit_branch} branch" if messages.empty?
      else
        messages << "#{commit_branch} branch is deleted, but not configured for automatic branch projects creation, skipping processing"
      end

      messages
    end
  end
end