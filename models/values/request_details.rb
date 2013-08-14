module GitlabWebHook
  class RequestDetails
    def is_valid?
      url = repository_url
      return false unless url && !url.strip.empty?
      true
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

    def full_branch_reference
      raise NameError.new("should be implemented in concrete implementation")
    end

    def branch
      ref = full_branch_reference
      return "" unless ref

      refs = ref.split("/")
      refs.reject { |ref| ref =~ /\A(ref|head)s?\z/ }.join("/")
    end

    def safe_branch
      branch.gsub("/", "_")
    end

    def is_delete_branch_commit?
      raise NameError.new("should be implemented in concrete implementation")
    end

    def commits
      raise NameError.new("should be implemented in concrete implementation")
    end

    def commits_count
      commits ? commits.size : 0
    end

    def payload
      raise NameError.new("should be implemented in concrete implementation")
    end
  end
end
