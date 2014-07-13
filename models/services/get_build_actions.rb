require_relative 'get_parameters_values'

include Java

java_import Java.hudson.model.ParametersAction

module GitlabWebHook
  class GetBuildActions
    def with(project, details)
      raise ArgumentError.new("project is required") unless project
      raise ArgumentError.new("details are required") unless details

      return [] unless project.parametrized? # no need to process if not parameterized

      ParametersAction.new(GetParametersValues.new.with(project, details))
    end
  end
end