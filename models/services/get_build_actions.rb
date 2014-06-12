include Java

java_import Java.hudson.model.ParametersAction
java_import Java.hudson.model.StringParameterValue

module GitlabWebHook
  class GetBuildActions
    def with(project, details)
      validate(project, details)

      # no need to process if not parameterized
      return [] unless project.is_parametrized?

      # no need to process if parameter list does not contain branch spec
      branch_parameter = project.get_branch_name_parameter
      return [] unless branch_parameter

      # @see hudson.model.AbstractProject#getDefaultParametersValues
      parameters_values = project.get_default_parameters.reject { |parameter| parameter.name == branch_parameter.name }.collect { |parameter| parameter.getDefaultParameterValue() }.reject { |value| value.nil? }
      parameters_values << StringParameterValue.new(branch_parameter.name, details.branch)
      parameters_values << StringParameterValue.new('repository_id', details.repository_id)
      ParametersAction.new(parameters_values)
    end

    private

    def validate(project, details)
      raise ArgumentError.new("project is required") unless project
      raise ArgumentError.new("details are required") unless details
    end
  end
end