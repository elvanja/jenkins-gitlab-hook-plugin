require 'rexml/document'

java_import Java.hudson.BulkChange
java_import Java.hudson.model.listeners.SaveableListener

class GitlabWebHookRootActionDescriptor < Jenkins::Model::DefaultDescriptor
    # TODO a hook to delete artifacts from the feature branches would be nice

    def initialize(*args)
      super
      load
    end

    def load
      return unless configFile.file.exists()
      xmlfile = File.new(configFile.file.canonicalPath)
      xmldoc = REXML::Document.new(xmlfile)
      if xmldoc.root

        @automatic_project_creation = xmldoc.root.elements['automatic_project_creation'].text == "true" ? true : false
        @use_master_project_name = xmldoc.root.elements['use_master_project_name'].text == "true" ? true : false

        @master_branch = xmldoc.root.elements['master_branch'].text
        @description = xmldoc.root.elements['description'].text
        @any_branch_pattern = xmldoc.root.elements['any_branch_pattern'].text

      end
    end

    def configure(req, form)
      parse(form)
      save
    end

    def save
      return if BulkChange.contains(self)

      doc = REXML::Document.new
      doc.add_element( 'hudson.model.Descriptor' , { "plugin" => "gitlab-hook" } )

      doc.root.add_element( 'automatic_project_creation' ).add_text( automatic_project_creation.to_s )
      doc.root.add_element( 'master_branch' ).add_text( master_branch )
      doc.root.add_element( 'use_master_project_name' ).add_text( use_master_project_name.to_s )
      doc.root.add_element( 'description' ).add_text( description )
      doc.root.add_element( 'any_branch_pattern' ).add_text( any_branch_pattern )

      f = File.open(configFile.file.canonicalPath, 'wb')
      f.puts("<?xml version='#{doc.version}' encoding='#{doc.encoding}'?>")

      formatter = REXML::Formatters::Pretty.new
      formatter.compact = true
      formatter.write doc, f

      f.close

      SaveableListener.fireOnChange(self, configFile)
      f.closed?
    end

    def automatic_project_creation?
      automatic_project_creation
    end

    def master_branch
      @master_branch || "master"
    end

    def use_master_project_name?
      use_master_project_name
    end

    def description
      @description || "Automatically created by Gitlab Web Hook plugin"
    end

    def any_branch_pattern
      @any_branch_pattern || "**"
    end

    def templated_jobs
      @templates || {}
    end

    private

    def parse(form)
      @automatic_project_creation = form["autocreate"] ? true : false
      if automatic_project_creation?
        @master_branch              = form["autocreate"]["master_branch"]
        @use_master_project_name    = form["autocreate"]["use_master_project_name"]
        @description                = form["autocreate"]["description"]
        @any_branch_pattern         = form["autocreate"]["any_branch_pattern"]
      end
    end

    def automatic_project_creation
      @automatic_project_creation.nil? ? false : @automatic_project_creation
    end

    def use_master_project_name
      @use_master_project_name.nil? ? false : @use_master_project_name
    end

end
