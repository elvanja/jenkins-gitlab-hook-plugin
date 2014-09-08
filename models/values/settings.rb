require 'rexml/document'

module GitlabWebHook
  class Settings
    # TODO a hook to delete artifacts from the feature branches would be nice

    # TODO: bring this into the UI / project configuration
    # default params should be available, configuration overrides them
    CREATE_PROJECTS_FOR_NON_MASTER_BRANCHES_AUTOMATICALLY = false
    USE_MASTER_PROJECT_NAME = false

    def initialize(*args)
      xmlconf = '/var/lib/jenkins/gitlab-hook-GitlabWebHookRootAction.xml'
      if File.exists?(xmlconf)
        xmlfile = File.new(xmlconf)
        xmldoc = REXML::Document.new(xmlfile)
        xmldoc.root.elements.each do |e|
          instance_variable_set "@#{e.name}", e.text
        end
      end
    end

    def automatic_project_creation?
      CREATE_PROJECTS_FOR_NON_MASTER_BRANCHES_AUTOMATICALLY
    end

    def master_branch
      @master_branch || "master"
    end

    def use_master_project_name?
      USE_MASTER_PROJECT_NAME
    end

    def description
      @description || "automatically created by Gitlab Web Hook plugin"
    end

    def any_branch_pattern
      @any_branch_pattern || "**"
    end
  end
end
