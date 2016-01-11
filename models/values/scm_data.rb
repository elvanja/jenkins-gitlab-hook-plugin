require_relative '../exceptions/configuration_exception'

module GitlabWebHook
  class ScmData
    attr_reader :source_scm, :details, :url, :name, :branchlist, :credentials, :refspec

    def initialize(source_scm, details, is_template=false)
      @source_scm = source_scm
      @details = details
      from_config(@source_scm.getUserRemoteConfigs().first, is_template)
      raise ConfigurationException.new('remote repo clone url not found') unless valid?
    end

    private

    def from_config(config, is_template=false)
        raise ConfigurationException.new('No git configuration found') unless  config
        @url = is_template ? details.repository_url : config.getUrl()
        @name = config.getName() || 'origin'
        @credentials = config.getCredentialsId()
        if is_template
          @branchlist = source_scm.getBranches()
        else
          branch = "#{@name}/#{@details.branch}"
          @branchlist = java.util.ArrayList.new([BranchSpec.new(branch).java_object])
        end
        @refspec = config.getRefspec()
    end

    def valid?
      !@url.to_s.empty?
    end
  end
end
