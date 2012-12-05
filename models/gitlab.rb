module Jenkins
  class Plugin
    class Proxies
      class GitlabDescriptor < Java.hudson.matrix.AxisDescriptor
        # the following module overrides various methods in Java.hudson.model.Descriptor
        # to make it work with Ruby. You must include this.
        #include Jenkins::Model::RubyDescriptor
        include Jenkins::Model::Descriptor

        def initialize
          puts "initialized GitlabDescriptorProxy"
        end
      end

      class GitlabProxy < Java.hudson.matrix.Axis
        # the following 2 modules implement the Describable interface
        # You must include this.
        #include Jenkins::Plugin::Proxies::Describable
        include Jenkins::Model::DescribableProxy
        #include Java.jenkins.ruby.Get
        #include Jenkins::Model::Describable

        # this module makes this class act as a proxy
        # You must include this, too
        include Jenkins::Plugin::Proxy

        # when the glue layer needs to create a wrapper, it calls this constructor
        # plugin refers to the Ruby plugin object, and the 'object' parameter
        # refers to JM::Foo that it's wrapping.
        def initialize(plugin, object)
          super(plugin, object, object.name, object.values) # '...' portion is for the constructor arguments to Foo
        end
      end
    end
  end
end

class Gitlab
  include Jenkins::Model
  include Jenkins::Model::Describable

  describe_as Java.hudson.matrix.Axis
  descriptor_is Jenkins::Plugin::Proxies::GitlabDescriptor

  attr_reader :name, :values

  def initialize(name, values)
    puts "initialized Gitlab"

    @name = name
    if String === values then
      @values = values.split(/[ \t\r\n]+/)
    else
      @values = values
    end

    puts "name = #{name}"
    puts "values = #{values}"
  end

  Jenkins::Plugin::Proxies::register self, Jenkins::Plugin::Proxies::GitlabProxy
end

class MyGitlab < Gitlab
  display_name "Gitlab"

  def initialize(attrs)
    puts "initialized MyGitlab"
    super("GitlabRVM", fix_empty(attrs['valueString']))
  end

  private

  def fix_empty(s)
    s == "" ? nil : s
  end
end
