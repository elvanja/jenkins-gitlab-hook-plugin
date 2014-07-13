include Java

java_import Java.org.eclipse.jgit.transport.URIish

module GitlabWebHook
  class RepositoryUri
    attr_reader :url

    def initialize(url)
      @url = url
      @uri = parse_url(url)
    end

    def matches?(other_uri)
      parse_uri(other_uri) == parse_uri(@uri)
    end

    def host
      @uri ? @uri.host : ""
    end

    private

    def parse_url(url)
      begin
        # explicitly using the correct constructor to remove annoying warning
        return (URIish.java_class.constructor(java.lang.String).new_instance(url)).to_java(URIish)
      rescue
      end
    end

    def parse_uri(uri)
      return nil, nil unless uri
      return normalize_host(uri.host), normalize_path(uri.path)
    end

    def normalize_host(host)
      return unless host
      host.downcase
    end

    def normalize_path(path)
      return unless path

      path.slice!(0) if path.start_with?('/')
      path.slice!(-1) if path.end_with?('/')
      path.slice!(-4..-1) if path.end_with?('.git')
      path.downcase
    end
  end
end
