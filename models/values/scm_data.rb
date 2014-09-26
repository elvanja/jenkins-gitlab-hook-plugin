require_relative '../exceptions/configuration_exception'

module GitlabWebHook
  class ScmData
    attr_reader :source_scm, :details, :url, :name, :branchlist, :credentials, :refspec
    
    def initialize(source_scm, details, is_template=false)
      @source_scm = source_scm
      @details = details
      from_config(@source_scm.getUserRemoteConfigs().first)
      raise ConfigurationException.new('remote repo clone url not found') unless valid?
    end

    private

    def from_config(config, is_template=false)
      if config
        @url = is_template ? details.repository_url : config.getUrl()
        @name = config.getName()
        @credentials = config.getCredentialsId()
        if is_template
          @branchlist = source_scm.getBranches()
        else
          branch = @name.to_s.size > 0 ? "#{@name}/#{@details.branch}" : @details.branch
          @branchlist = [BranchSpec.new(branch)]
        end
        @refspec = config.getRefspec()
      end
    end

    def valid?
      !@url.to_s.empty?
    end
  end
end
