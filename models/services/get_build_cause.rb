include Java

java_import Java.hudson.model.Cause

module GitlabWebHook
  class GetBuildCause
    def with(details)
      raise ArgumentError.new("details are required") unless details

      notes = details.payload ? from_payload(details) : ["no payload available"]
      Cause::RemoteCause.new(details.repository_uri.host, notes.join("<br/>"))
    end

    def from_payload(details)
      notes = ["<br/>"]
      notes << "triggered by push on branch #{details.full_branch_reference}"
      notes << "with #{details.commits_count} commit#{details.commits_count == "1" ? "" : "s" }:"
      details.commits.each do |commit|
        notes << "* <a href=\"#{commit.url}\">#{commit.message}</a>"
      end
      notes
    end
  end
end