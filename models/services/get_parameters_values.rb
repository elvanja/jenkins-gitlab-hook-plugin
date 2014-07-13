include Java

java_import Java.hudson.model.StringParameterDefinition
java_import Java.hudson.model.StringParameterValue

module GitlabWebHook
  class GetParametersValues
    def with(project, details)
      validate(project, details)

      values = build_from_payload_or_default(details, project)
      remove_empty(values)
      apply_branch(project, details, values)

      values
    end

    private

    def build_from_payload_or_default(details, project)
      project.get_default_parameters.collect do |parameter|
        from_payload(parameter, details.flat_payload) || parameter.getDefaultParameterValue()
      end
    end

    def remove_empty(values)
      values.reject! { |value| value.nil? }
    end

    def apply_branch(project, details, values)
      branch_parameter = project.get_branch_name_parameter
      if branch_parameter
        values.reject! { |value| value.name.downcase == branch_parameter.name.downcase }
        values << StringParameterValue.new(branch_parameter.name, details.branch)
      end
    end

    def from_payload(parameter, payload)
      # TODO possibly support other types as well?
      return nil unless parameter.java_kind_of?(StringParameterDefinition)

      value = payload.find { |key, _| key.downcase == parameter.name.downcase }.to_a[1]
      value.nil? ? value : StringParameterValue.new(parameter.name, value.to_s.strip)
    end

    def validate(project, details)
      raise ArgumentError.new("project is required") unless project
      raise ArgumentError.new("details are required") unless details
    end
  end
end