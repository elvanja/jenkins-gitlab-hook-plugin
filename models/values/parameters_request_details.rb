require_relative 'request_details'

module GitlabWebHook
  class ParametersRequestDetails < RequestDetails
    attr_reader :parameters

    def initialize(parameters)
      @kind = 'parameters'
      @parameters = parameters || raise(ArgumentError.new("request parameters are required"))
    end

    def repository_url
      url = nil
      [:repo_url, :url, :repository_url].each do |key|
        url ||= parameters[key]
        url ||= parameters[key.to_s]
      end
      url ? url.strip : ""
    end

    def repository_name
      name = nil
      [:repo_name, :name, :repository_name].each do |key|
        name ||= parameters[key]
        name ||= parameters[key.to_s]
      end
      name ? name.strip : ""
    end

    def repository_homepage
      homepage = nil
      [:repo_homepage, :homepage, :repository_homepage].each do |key|
        homepage ||= parameters[key]
        homepage ||= parameters[key.to_s]
      end
      homepage ? homepage.strip : ""
    end

    def full_branch_reference
      ref = nil
      [:ref, :branch, :branch_reference].each do |key|
        ref ||= parameters[key]
        ref ||= parameters[key.to_s]
      end
      ref ? ref.strip : ""
    end

    def delete_branch_commit?
      delete = nil
      [:delete_branch_commit, :delete].each do |key|
        delete ||= parameters[key]
        delete ||= parameters[key.to_s]
      end
      return false unless delete
      delete.to_s != "0" || delete
    end

  end
end
