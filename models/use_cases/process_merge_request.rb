require_relative '../services/get_jenkins_projects'
require_relative 'create_project_for_branch.rb'

module GitlabWebHook
  class ProcessMergeRequest

    def initialize(get_jenkins_projects = GetJenkinsProjects.new, create_project_for_branch = CreateProjectForBranch.new)
      @get_jenkins_projects = get_jenkins_projects
      @create_project_for_branch = create_project_for_branch
    end

    def with(details)
      messages = []
      if details.merge_status == 'cannot_be_merged' && details.state != 'closed'
        messages << "Skipping not ready merge request for #{details.repository_name} with #{details.merge_status} status"
      else
        candidates = @get_jenkins_projects.matching_uri(details)
        return [ 'No merge-request project candidates'] unless candidates

        candidates.select! do |project|
          project.matches?(details, details.branch, true) && project.merge_to?(details.target_branch)
        end

        case details.state
        when 'opened', 'reopened'
          if candidates.any?
            candidates.each do |project|
             messages << "Already created #{project.name} for #{details.branch} -> #{details.target_branch}"
             messages << BuildNow.new(project).with(details)
           end
          else
            projects = @create_project_for_branch.for_merge(details)
            if projects.any?
              projects.each do |project|
                messages << "Created #{project.name} for #{details.branch} from #{details.repository_name}"
                messages << BuildNow.new(project).with(details)
              end
            else
              messages << "No project candidate for merging #{details.safe_branch}"
            end
          end
        when 'closed', 'merged'
          candidates.each do |project|
            project.delete
            messages << "Deleting merge-request project #{project.name}"
          end
        else
          messages << "Skipping request : merge request status is '#{details.state}'"
        end
      end
      messages
    end

  end
end
