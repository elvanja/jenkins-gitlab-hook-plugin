include Java

java_import Java.hudson.model.Cause
java_import Java.org.eclipse.jgit.transport.URIish

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

      repo_uri = URIish.new(details.repository_url)

      Cause::RemoteCause.new(repo_uri.host, notes.join("<br/>"))
    end

    private

    def validate(details)
      raise ArgumentError.new("details are required") unless details
    end
  end
end