require 'gitlab'

class GitlabNotifier < Jenkins::Tasks::Publisher

  display_name 'Gitlab commit status publisher'

  transient :descriptor, :client

  attr_reader :descriptor, :client
  attr_reader :project

  def initialize(attrs)
    create_client
  end

  def read_completed
    create_client
  end

  def prebuild(build, listener)
    client.name = repo_namespace(build)
    return unless descriptor.commit_status?
    env = build.native.environment listener
    sha = post_commit env['GIT_COMMIT'] , build, listener
    client.post_status( sha , 'running' , env['BUILD_URL'] )
  end

  def perform(build, launcher, listener)
    mr_id = client.merge_request(project)
    return if mr_id == -1 && descriptor.mr_status_only?
    env = build.native.environment listener
    sha = post_commit env['GIT_COMMIT'] , build, listener
    client.post_status( sha , build.native.result , env['BUILD_URL'] , descriptor.commit_status? ? nil : mr_id )
  end

  class GitlabNotifierDescriptor < Jenkins::Model::DefaultDescriptor

    java_import Java.hudson.BulkChange
    java_import Java.hudson.model.listeners.SaveableListener

    attr_reader :gitlab_url, :token

    def commit_status?
      @commit_status == 'true'
    end

    def mr_status_only?
      @mr_status_only == 'true'
    end

    def initialize(describable, object, describable_type)
      super
      load
    end

    def load
      return unless configFile.file.exists()
      xmlfile = File.new(configFile.file.canonicalPath)
      xmldoc = REXML::Document.new(xmlfile)
      if xmldoc.root
        @gitlab_url = xmldoc.root.elements['gitlab_url'].text
        @token = xmldoc.root.elements['token'].text
        @commit_status = xmldoc.root.elements['commit_status'].nil? ? 'false' : xmldoc.root.elements['commit_status'].text
        @mr_status_only = xmldoc.root.elements['mr_status_only'].nil? ? 'true' : xmldoc.root.elements['mr_status_only'].text
      end
    end

    def configure(req, form)
      parse(form)
      save
    end

    def save
      return if BulkChange.contains(self)

      doc = REXML::Document.new
      doc.add_element( 'hudson.model.Descriptor' , { "plugin" => "gitlab-notifier" } )

      doc.root.add_element( 'gitlab_url' ).add_text( gitlab_url )
      doc.root.add_element( 'token' ).add_text( token )
      doc.root.add_element( 'commit_status' ).add_text( @commit_status )
      doc.root.add_element( 'mr_status_only' ).add_text( @mr_status_only )

      f = File.open(configFile.file.canonicalPath, 'wb')
      f.puts("<?xml version='#{doc.version}' encoding='#{doc.encoding}'?>")

      formatter = REXML::Formatters::Pretty.new
      formatter.compact = true
      formatter.write doc, f

      f.close

      SaveableListener.fireOnChange(self, configFile)
      f.closed?
    end

    private

    def parse(form)
      @gitlab_url = form["gitlab_url"]
      @token = form['token']
      @commit_status = form['commit_status'] ? 'true' : 'false'
      @mr_status_only = form['mr_status_only'] ? 'true' : 'false'
    end

  end

  describe_as Java.hudson.tasks.Publisher, :with => GitlabNotifierDescriptor

  private

  def clone_dir( build )
    if local_branch = GitlabWebHook::Project.new(build.native.project).local_clone
      build.workspace + local_branch
    else
      build.workspace
    end
  end

  def post_commit(current, build, listener)
    gitlog = StringIO.new
    launcher = build.workspace.create_launcher(listener)
    if launcher.execute('git', 'log', '-1', '--oneline' ,'--format=%P', {:out => gitlog, :chdir => clone_dir(build)} ) == 0
      parents = gitlog.string.split
    else
      listener.warning( "git-log failed : '#{parents.join(' ')}'" )
    end
    parents[0] = current
    parents.last
  end

  def create_client
    @descriptor = Jenkins::Plugin.instance.descriptors[GitlabNotifier]
    @client = Gitlab::Client.new @descriptor
  end

  def repo_namespace(build)
    @project = GitlabWebHook::Project.new build.native.project
    repo_url = @project.scm.repositories.first.getURIs.first
    repo_url.to_s.split(':')[1]
  end

end
