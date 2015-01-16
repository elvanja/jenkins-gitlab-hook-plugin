require_relative 'abstract_details'
require_relative '../services/flat_keys_hash'

module GitlabWebHook
  class RequestDetails < AbstractDetails

    def valid?
      repository_url.to_s.strip.empty? ? false : true
    end

    def branch
      ref = full_branch_reference
      return "" unless ref

      refs = ref.split("/")
      refs.reject { |ref| ref =~ /\A(ref|head|tag)s?\z/ }.join("/")
    end

    def tagname
      return nil unless full_branch_reference.start_with?('refs/tags/')
      full_branch_reference.sub('refs/tags/', '')
    end

    def delete_branch_commit?
      raise NameError.new("should be implemented in concrete implementation")
    end

    def commits
      commits = get_commits || []
      raise ArgumentError.new("payload must be an array") unless commits.is_a?(Array)
      commits
    end

    def commits_count
      commits ? commits.size : 0
    end

    def flat_payload
      @flat_payload ||= payload.extend(FlatKeysHash).to_flat_keys.tap do |flattened|
        [
          :repository_url,
          :repository_name,
          :repository_homepage,
          :full_branch_reference,
          :branch
        ].each { |detail| flattened[detail.to_s] = self.send(detail) }
        flattened['tagname'] = tagname unless tagname.nil?
      end
    end

    private

    def get_commits
    end

  end
end
