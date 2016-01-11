include Java

java_import Java.hudson.model.Cause

module GitlabWebHook
  class GetBuildCause
    def with(details)
      raise ArgumentError.new('details are required') unless details

      notes = details.payload ? from_payload(details) : 'no payload available'
      Cause::RemoteCause.new(details.repository_uri.host, notes)
    end

    def from_payload(details)
      notes = "triggered by "
      if details.kind == 'merge_request'
        notes += "merge request #{details.branch} -> #{details.target_branch}"
      elsif details.tagname.nil?
        notes += "push on branch #{details.branch} with "
        if details.commits_count == '1'
          notes += "one commit"
        else
          notes += "#{details.commits_count} commits"
        end
      else
        notes += "tag #{details.tagname}"
      end
      notes
    end
  end
end
