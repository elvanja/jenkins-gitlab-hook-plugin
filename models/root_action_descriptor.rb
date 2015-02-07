require 'rexml/document'

java_import Java.hudson.BulkChange
java_import Java.hudson.model.listeners.SaveableListener

class GitlabWebHookRootActionDescriptor < Jenkins::Model::DefaultDescriptor
  # TODO a hook to delete artifacts from the feature branches would be nice

  AUTOMATIC_PROJECT_CREATION_PROPERTY = 'automatic_project_creation'
  MASTER_BRANCH_PROPERTY = 'master_branch'
  USE_MASTER_PROJECT_NAME_PROPERTY = 'use_master_project_name'
  DESCRIPTION_PROPERTY = 'description'

  def initialize(*args)
    super
    load
  end

  def automatic_project_creation?
    !!@automatic_project_creation
  end

  def master_branch
    @master_branch || "master"
  end

  def use_master_project_name?
    !!@use_master_project_name
  end

  def description
    @description || "Automatically created by Gitlab Web Hook plugin"
  end

  def load
    return unless configFile.file.exists()

    doc = REXML::Document.new(File.new(configFile.file.canonicalPath))
    if doc.root
      @automatic_project_creation   = read_property(doc, AUTOMATIC_PROJECT_CREATION_PROPERTY) == "true"
      @use_master_project_name      = read_property(doc, USE_MASTER_PROJECT_NAME_PROPERTY) == "true"
      @master_branch                = read_property(doc, MASTER_BRANCH_PROPERTY)
      @description                  = read_property(doc, DESCRIPTION_PROPERTY)
    end
  end

  def configure(req, form)
    parse(form)
    save
  end

  def save
    return if BulkChange.contains(self)

    doc = REXML::Document.new
    doc.add_element('hudson.model.Descriptor', {"plugin" => "gitlab-hook"})

    write_property(doc, AUTOMATIC_PROJECT_CREATION_PROPERTY, automatic_project_creation?)
    write_property(doc, MASTER_BRANCH_PROPERTY, master_branch)
    write_property(doc, USE_MASTER_PROJECT_NAME_PROPERTY, use_master_project_name?)
    write_property(doc, DESCRIPTION_PROPERTY, description)

    f = File.open(configFile.file.canonicalPath, 'wb')
    f.puts("<?xml version='#{doc.version}' encoding='#{doc.encoding}'?>")

    formatter = REXML::Formatters::Pretty.new
    formatter.compact = true
    formatter.write(doc, f)

    f.close

    SaveableListener.fireOnChange(self, configFile)
    f.closed?
  end

  private

  def parse(form)
    @automatic_project_creation = form[AUTOMATIC_PROJECT_CREATION_PROPERTY] ? true : false
    if automatic_project_creation?
      @master_branch              = form[AUTOMATIC_PROJECT_CREATION_PROPERTY][MASTER_BRANCH_PROPERTY]
      @use_master_project_name    = form[AUTOMATIC_PROJECT_CREATION_PROPERTY][USE_MASTER_PROJECT_NAME_PROPERTY]
      @description                = form[AUTOMATIC_PROJECT_CREATION_PROPERTY][DESCRIPTION_PROPERTY]
    end
  end

  def read_property(doc, property)
    doc.root.elements[property].text
  end

  def write_property(doc, property, value)
    doc.root.add_element(property).add_text(value.to_s)
  end
end
