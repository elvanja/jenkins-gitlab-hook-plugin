require_relative '../exceptions/not_found_exception'
require_relative '../values/project'
require_relative '../util/settings'

include Java

java_import Java.hudson.model.AbstractProject
java_import Java.hudson.security.ACL

java_import Java.org.acegisecurity.Authentication
java_import Java.org.acegisecurity.context.SecurityContextHolder

java_import Java.hudson.plugins.git.GitSCM
java_import Java.hudson.plugins.git.BranchSpec
java_import Java.hudson.plugins.git.UserRemoteConfig
java_import Java.hudson.plugins.git.browser.GitLab
java_import Java.hudson.plugins.git.util.DefaultBuildChooser

module GitlabWebHook
  class GetJenkinsProjects
    include Settings

    LOGGER = Logger.getLogger(GetJenkinsProjects.class.name)

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
        project.matches?(details, settings.any_branch_pattern)
      end

      # find project for the repo and master branch
      # use any other branch matching the repo
      projects.find { |project| project.matches?(details, settings.master_branch, true) } || projects.first
    end

    private

    def all
      old_authentication_level = elevate_priviledges
      projects = Java.jenkins.model.Jenkins.instance.getAllItems(AbstractProject.java_class).map do |jenkins_project|
        Project.new(jenkins_project)
      end
      revert_priviledges(old_authentication_level)
      projects
    end

    # set system priviledges to be able to see all projects
    # see https://wiki.jenkins-ci.org/display/JENKINS/Git+Plugin hudson.plugins.git.GitStatus#doNotifyCommit comments for details
    def elevate_priviledges
      old_authentication_level = SecurityContextHolder.getContext().getAuthentication()
      SecurityContextHolder.getContext().setAuthentication(ACL::SYSTEM)
      old_authentication_level
    end

    def revert_priviledges(old_authentication_level)
      SecurityContextHolder.getContext().setAuthentication(old_authentication_level) if old_authentication_level
    end

    def log_matched(projects)
      LOGGER.info(['matching projects:'].concat(projects.map { |project| "   - #{project}" }).join("\n"))
    end
  end
end
