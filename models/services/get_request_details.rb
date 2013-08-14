require_relative '../values/parameters_request_details'
require_relative '../values/payload_request_details'
require_relative '../exceptions/bad_request_exception'

module GitlabWebHook
  class GetRequestDetails
    def from(params, request)
      details = ParametersRequestDetails.new(params)
      return details if details.is_valid?

      body = read_request_body(request)
      details = PayloadRequestDetails.new(JSON.parse(body))

      raise BadRequestException.new("repo url not found in Gitlab payload or the HTTP parameters #{[params.inspect, body].join(",")}") unless details.is_valid?

      return details
    end

    private

    def read_request_body(request)
      begin
        request.body.rewind
        return request.body.read
      rescue
      end

      return ""
    end
  end
end
