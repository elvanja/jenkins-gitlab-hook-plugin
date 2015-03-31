require_relative 'request_details'

module GitlabWebHook
  class PayloadRequestDetails < RequestDetails
    def initialize(payload)
      @kind = 'webhook'
      @payload = payload || raise(ArgumentError.new("request payload is required"))
    end

    def repository_url
      return "" unless payload["repository"]
      return "" unless payload["repository"]["url"]
      payload["repository"]["url"].strip
    end

    def repository_group
      return "" unless repository_homepage
      repository_homepage.split('/')[-2]
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
      payload["ref"].to_s.strip
    end

    def delete_branch_commit?
      after = payload["after"]
      after ? (after.strip.squeeze == "0") : false
    end

    private

    def get_commits
      @commits ||= payload["commits"].to_a.map do |commit|
        Commit.new(commit["url"], commit["message"])
      end
    end

    def get_payload
      @payload
    end
  end
end
