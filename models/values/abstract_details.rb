
module GitlabWebHook
  class AbstractDetails

    attr_accessor :kind

    def valid?
      raise NameError.new("should be implemented in concrete implementation")
    end

    def repository_uri
      RepositoryUri.new(repository_url)
    end

    def repository_url
      raise NameError.new("should be implemented in concrete implementation")
    end

    def repository_name
      raise NameError.new("should be implemented in concrete implementation")
    end

    def repository_homepage
      raise NameError.new("should be implemented in concrete implementation")
    end

    def branch
      raise NameError.new("should be implemented in concrete implementation")
    end

    def full_branch_reference
      raise NameError.new("should be implemented in concrete implementation")
    end

    def safe_branch
      branch.gsub("/", "_")
    end

    def payload
      payload = get_payload || {}
      raise ArgumentError.new("payload must be a hash") unless payload.is_a?(Hash)
      payload
    end

    def classic?
      ['webhook', 'parameters'].include?(kind) && !repository_url.to_s.strip.empty?
    end

    private

    def get_payload
    end
  end
end
