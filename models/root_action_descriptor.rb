require 'rexml/document'

class GitlabWebHookRootActionDescriptor < Jenkins::Model::DefaultDescriptor
    # TODO a hook to delete artifacts from the feature branches would be nice

    def initialize(*args)
      super
      load
    end

    def load
      xmlconf = '/var/lib/jenkins/gitlab-hook-GitlabWebHookRootAction.xml'
      if File.exists?(xmlconf)
        xmlfile = File.new(xmlconf)
        xmldoc = REXML::Document.new(xmlfile)
        xmldoc.root && xmldoc.root.elements.each do |e|
          instance_variable_set "@#{e.name}", e.text
        end
      end
    end

    def configure(req, form)
      parse(form)
      save
    end

    def save
      xmlconf = '/var/lib/jenkins/gitlab-hook-GitlabWebHookRootAction.xml'
      f = File.open(xmlconf, 'wb')
      f.write(<<-EOS)
<?xml version='1.0' encoding='UTF-8'?>
<hudson.model.Descriptor plugin="gitlab-hook">
  <master_branch>#{master_branch}</master_branch>
  <any_branch_pattern>#{any_branch_pattern}</any_branch_pattern>
  <use_master_project_name>#{use_master_project_name}</use_master_project_name>
  <automatic_project_creation>#{automatic_project_creation}</automatic_project_creation>
  <description>#{description}</description>
</hudson.model.Descriptor>
EOS
      f.close
    end

    def automatic_project_creation
      @automatic_project_creation || "false"
    end

    def automatic_project_creation?
      to_boolean(@automatic_project_creation) || false
    end

    def master_branch
      @master_branch || "master"
    end

    def use_master_project_name
      @use_master_project_name || "false"
    end

    def use_master_project_name?
      to_boolean(@use_master_project_name) || false
    end

    def description
      @description || "Automatically created by Gitlab Web Hook plugin"
    end

    def any_branch_pattern
      @any_branch_pattern || "**"
    end

    private

    def parse(form)
      @automatic_project_creation = form["automatic_project_creation"]
      @master_branch              = form["master_branch"]
      @use_master_project_name    = form["use_master_project_name"]
      @description                = form["description"]
      @any_branch_pattern         = form["any_branch_pattern"]
    end

    def to_boolean(str)
      return true if str=="true"
      return false
    end

end
