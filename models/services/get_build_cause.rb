include Java

java_import Java.hudson.model.Cause
java_import Java.org.eclipse.jgit.transport.URIish

module GitlabWebHook
  class GetBuildCause
    def with(details)
      repo_uri = URIish.new(details.repository_url)

      if details.payload
        notes = ["<br/>"]
        notes << "triggered by push on branch #{details.full_branch_reference}"
        notes << "with #{details.commits_count} commit#{details.commits_count == "1" ? "" : "s" }:"
        details.commits.each do |commit|
          notes << "* <a href=\"#{commit.url}\">#{commit.message}</a>"
        end
      else
        notes ["no payload available"]
      end

      Cause::RemoteCause.new(repo_uri.host, notes.join("<br/>"))
    end
  end
end