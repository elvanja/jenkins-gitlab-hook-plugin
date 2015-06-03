require 'rexml/document'

java_import Java.hudson.BulkChange
java_import Java.hudson.model.listeners.SaveableListener

class GitlabWebHookRootActionDescriptor < Jenkins::Model::DefaultDescriptor
  # TODO a hook to delete artifacts from the feature branches would be nice

  MERGE_REQUEST_PROCESSING = 'merge_request_processing'
  MERGED_BRANCH_PROCESSING = 'merged_branch_triggering'
  AUTOMATIC_PROJECT_CREATION_PROPERTY = 'automatic_project_creation'
  MASTER_BRANCH_PROPERTY = 'master_branch'
  USE_MASTER_PROJECT_NAME_PROPERTY = 'use_master_project_name'
  DESCRIPTION_PROPERTY = 'description'

  def initialize(*args)
    super
    begin
      load
    rescue Exception => ex
      logger.severe "Cannot load globan plugin configuration : #{ex}"
    end
  end

  def merge_request_processing?
    !!@merge_request_processing
  end

  def merged_branch_triggering?
    !!@merged_branch_triggering
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
      @merge_request_processing     = read_property(doc, MERGE_REQUEST_PROCESSING, "true") == "true"
      @merged_branch_triggering     = read_property(doc, MERGED_BRANCH_PROCESSING, "false") == "true"
      @automatic_project_creation   = read_property(doc, AUTOMATIC_PROJECT_CREATION_PROPERTY) == "true"
      @use_master_project_name      = read_property(doc, USE_MASTER_PROJECT_NAME_PROPERTY) == "true"
      @master_branch                = read_property(doc, MASTER_BRANCH_PROPERTY)
      @description                  = read_property(doc, DESCRIPTION_PROPERTY)
      @templates                    = get_templates doc.root.elements['templates']
      @group_templates              = get_templates doc.root.elements['group_templates']
      @template                     = doc.root.elements['template'] && doc.root.elements['template'].text
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

    write_property(doc, MERGE_REQUEST_PROCESSING, merge_request_processing?)
    write_property(doc, MERGED_BRANCH_PROCESSING, merged_branch_triggering?)
    write_property(doc, AUTOMATIC_PROJECT_CREATION_PROPERTY, automatic_project_creation?)
    write_property(doc, MASTER_BRANCH_PROPERTY, master_branch)
    write_property(doc, USE_MASTER_PROJECT_NAME_PROPERTY, use_master_project_name?)
    write_property(doc, DESCRIPTION_PROPERTY, description)

    doc.root.add_element( 'template' ).add_text( template_fallback )

    tpls = doc.root.add_element( 'templates' )
    templated_jobs.each do |k,v|
      new = tpls.add_element('template')
      new.add_element('string').add_text(k)
      new.add_element('project').add_text(v)
    end

    tpls = doc.root.add_element( 'group_templates' )
    templated_groups.each do |k,v|
      new = tpls.add_element('template')
      new.add_element('string').add_text(k)
      new.add_element('project').add_text(v)
    end

    f = File.open(configFile.file.canonicalPath, 'wb')
    f.puts("<?xml version='#{doc.version}' encoding='#{doc.encoding}'?>")

    formatter = REXML::Formatters::Pretty.new
    formatter.compact = true
    formatter.write(doc, f)

    f.close

    SaveableListener.fireOnChange(self, configFile)
    f.closed?
  end

  def templated_jobs
    @templates || {}
  end

  def templated_groups
    @group_templates || {}
  end

  def template_fallback
    @template
  end

  private

  def parse(form)
    @merge_request_processing = form[MERGE_REQUEST_PROCESSING] ? true : false
    @merged_branch_triggering = form[MERGED_BRANCH_PROCESSING] ? true : false
    @automatic_project_creation = form[AUTOMATIC_PROJECT_CREATION_PROPERTY] ? true : false
    if automatic_project_creation?
      @master_branch              = form[AUTOMATIC_PROJECT_CREATION_PROPERTY][MASTER_BRANCH_PROPERTY]
      @use_master_project_name    = form[AUTOMATIC_PROJECT_CREATION_PROPERTY][USE_MASTER_PROJECT_NAME_PROPERTY]
      @description                = form[AUTOMATIC_PROJECT_CREATION_PROPERTY][DESCRIPTION_PROPERTY]
    end
    @template = form['template']
    @templates = form['templates'] && form2list( form['templates'] ).inject({}) do |hash, item|
      hash.update( item['string'] => item['project'] )
    end
    @group_templates = form['group_templates'] && form2list( form['group_templates'] ).inject({}) do |hash, item|
      hash.update( item['string'] => item['project'] )
    end
  end

  def form2list(form_item)
    form_item.is_a?(Java::NetSfJson::JSONArray) ? form_item : [].push( form_item )
  end

  def get_templates(templates)
    return unless templates
    templates.elements.select{ |tpl| tpl.name == 'template' }.inject({}) do |hash, tpl|
      hash[tpl.elements['string'].text] = tpl.elements['project'].text
      hash
    end
  end

  def read_property(doc, property, default=nil)
    if item = doc.root.elements[property]
      return item.text
    end
    default
  end

  def write_property(doc, property, value)
    doc.root.add_element(property).add_text(value.to_s)
  end

  def logger
    @logger ||= Java.java.util.logging.Logger.getLogger(GitlabWebHookRootActionDescriptor.class.name)
  end
end
