include Java

java_import Java.hudson.model.Cause

module GitlabWebHook
  class GetBuildCause
    def with(details)
      validate(details)

      if details.payload
        notes = ["<br/>"]
        notes << "triggered by push on branch #{details.full_branch_reference}"
        notes << "with #{details.commits_count} commit#{details.commits_count == "1" ? "" : "s" }:"
        details.commits.each do |commit|
          notes << "* <a href=\"#{commit.url}\">#{commit.message}</a>"
        end
      else
        notes = ["no payload available"]
      end

      Cause::RemoteCause.new(details.repository_uri.host, notes.join("<br/>"))
    end

    private

    def validate(details)
      raise ArgumentError.new("details are required") unless details
    end
  end
end