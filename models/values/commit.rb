module GitlabWebHook
  class Commit
    attr_reader :url, :message

    def initialize(url, message)
      @url = url
      @message = message
    end
  end
end