require_relative '../settings'
require_relative '../project'
require_relative '../exceptions/not_found_exception'
require_relative '../use_cases/create_project_for_branch'

include Java

java_import Java.hudson.model.AbstractProject
java_import Java.hudson.security.ACL

java_import Java.org.eclipse.jgit.transport.URIish

java_import Java.org.acegisecurity.Authentication
java_import Java.org.acegisecurity.context.SecurityContextHolder

java_import Java.hudson.plugins.git.GitSCM
java_import Java.hudson.plugins.git.BranchSpec
java_import Java.hudson.plugins.git.UserRemoteConfig
java_import Java.hudson.plugins.git.browser.GitLab
java_import Java.hudson.plugins.git.util.DefaultBuildChooser

module GitlabWebHook
  class GetJenkinsProjects
    def matching(details)
      repo_uri = URIish.new(details.repository_url)
      commit_branch = details.branch

      projects = all.select do |project|
        project.matches?(repo_uri, commit_branch)
      end

      # TODO read these from some global object with settings
      if Settings.automatic_project_creation?
        #TODO move this to GetJenkinsProjects use case !!!
        projects.select! { |project| project.is_exact_match?(commit_branch) }
        # TODO remove circular dependency !!!
        projects << CreateProjectForBranch.new.with(details) if projects.empty?
      end
      raise NotFoundException.new("no project references the given repo url and commit branch") if projects.empty?

      projects
    end

    private

    def all
      return @all if @all

      old_authentication_level = elevate_priviledges()
      @all = Java.jenkins.model.Jenkins.instance.getAllItems(AbstractProject.java_class).map do |jenkins_project|
        Project.new(jenkins_project)
      end
      revert_priviledges(old_authentication_level)

      @all
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
  end
end