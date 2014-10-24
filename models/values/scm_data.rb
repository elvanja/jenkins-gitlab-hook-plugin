require_relative '../exceptions/configuration_exception'

module GitlabWebHook
  class ScmData
    attr_reader :source_scm, :details, :url, :name, :branch, :credentials
    
    def initialize(source_scm, details)
      @source_scm = source_scm
      @details = details
      from_config(@source_scm.getUserRemoteConfigs().first)
      raise ConfigurationException.new('remote repo clone url not found') unless valid?
    end

    private

    def from_config(config)
      if config
        @url = config.getUrl()
        @name = config.getName()
        @credentials = config.getCredentialsId()
        @branch = @name.to_s.size > 0 ? "#{@name}/#{@details.branch}" : @details.branch
      end
    end

    def valid?
      !@url.to_s.empty?
    end
  end
end
