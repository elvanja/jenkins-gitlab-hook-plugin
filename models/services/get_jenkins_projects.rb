require_relative '../exceptions/not_found_exception'
require_relative '../values/project'
require_relative '../util/settings'
require_relative '../services/security'

include Java

java_import Java.hudson.model.AbstractProject
java_import Java.hudson.matrix.MatrixConfiguration

java_import Java.hudson.plugins.git.GitSCM
java_import Java.hudson.plugins.git.BranchSpec
java_import Java.hudson.plugins.git.UserRemoteConfig
java_import Java.hudson.plugins.git.browser.GitLab
java_import Java.hudson.plugins.git.util.DefaultBuildChooser

module GitlabWebHook
  class GetJenkinsProjects
    include Settings

    attr_reader :logger

    def initialize(logger = Java.java.util.logging.Logger.getLogger(GetJenkinsProjects.class.name))
      @logger = logger
    end

    def matching_uri(details)
      all.select do |project|
        project.matches_uri?(details.repository_uri)
      end.tap { |projects| log_matched(projects) }
    end

    def named(name)
      all.select do |project|
        project.name == name
      end
    end

    def master(details)
      projects = all.select do |project|
        project.matches_uri?(details.repository_uri)
      end

      # find project for the repo and master branch
      # use any other branch matching the repo
      projects.find { |project| project.matches?(details, settings.master_branch, true) } || projects.first
    end

    private

    def all
      projects = nil
      Security.impersonate(ACL::SYSTEM) do
        projects = Java.jenkins.model.Jenkins.instance.getAllItems(AbstractProject.java_class).map do |jenkins_project|
          Project.new(jenkins_project) unless jenkins_project.java_kind_of?(MatrixConfiguration)
        end - [nil]
      end
      projects
    end

    def log_matched(projects)
      logger.info(['matching projects:'].concat(projects.map { |project| "   - #{project}" }).join("\n"))
    end
  end
end
