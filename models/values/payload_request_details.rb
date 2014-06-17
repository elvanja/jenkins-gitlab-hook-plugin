require_relative 'request_details'

module GitlabWebHook
  class PayloadRequestDetails < RequestDetails
    attr_reader :payload

    def initialize(payload)
      raise ArgumentError.new("request payload is required") unless payload
      @payload = payload
    end

    def repository_url
      return "" unless payload["repository"]
      return "" unless payload["repository"]["url"]
      payload["repository"]["url"].strip
    end

    def repository_name
      return "" unless payload["repository"]
      return "" unless payload["repository"]["name"]
      payload["repository"]["name"].strip
    end

    def repository_homepage
      return "" unless payload["repository"]
      return "" unless payload["repository"]["homepage"]
      payload["repository"]["homepage"].strip
    end

    def full_branch_reference
      return "" unless payload["ref"]
      payload["ref"].strip
    end

    def repository_id
      return "" unless payload["project_id"]
      payload["project_id"].to_s
    end

    def is_delete_branch_commit?
      after = payload["after"]
      return false unless after
      after.strip.squeeze == "0"
    end

    def commits
      return @commits if @commits

      commits_from_payload = payload["commits"]
      return [] unless commits_from_payload

      @commits = commits_from_payload.map do |commit|
        Commit.new(commit["url"], commit["message"])
      end
      @commits
    end
  end
end
