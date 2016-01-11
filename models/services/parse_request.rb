require 'json'

require_relative '../exceptions/bad_request_exception'
require_relative '../values/parameters_request_details'
require_relative '../values/payload_request_details'
require_relative '../values/merge_request_details'

module GitlabWebHook
  class ParseRequest
    EMPTY_BODY = '{}'

    def from(parameters, request)
      details = ParametersRequestDetails.new(parameters)
      return details if details.valid?

      body = read_request_body(request)
      details = PayloadRequestDetails.new(parse_request_body(body))
      return details if details.valid?

      details = MergeRequestDetails.new(parse_request_body(body))
      throw_bad_request_exception(body, parameters) unless details.valid?
      details
    end

    private

    def read_request_body(request)
      request.body.rewind
      body = request.body.read
      return body.empty? ? EMPTY_BODY : body
    rescue
      EMPTY_BODY
    end

    def parse_request_body(body)
      JSON.parse(body)
    rescue
      {}
    end

    def throw_bad_request_exception(body, parameters)
      raise BadRequestException.new([
          'repo url could not be found in Gitlab payload or the HTTP parameters:',
          "   - body: #{body}",
          "   - parameters: #{JSON.pretty_generate(parameters)}"
      ].join("\n"))
    end
  end
end
