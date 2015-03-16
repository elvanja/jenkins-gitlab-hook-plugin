require 'rake'
require 'rspec/core/rake_task'

task :default => :rspec

desc "Run all RSpec code examples"
RSpec::Core::RakeTask.new(:rspec)

SPEC_SUITES = (Dir.entries('spec') - ['.', '..','fixtures']).select {|e| File.directory? "spec/#{e}" }
namespace :rspec do
  SPEC_SUITES.each do |suite|
    desc "Run #{suite} RSpec code examples"
    RSpec::Core::RakeTask.new(suite) do |t|
      t.pattern = "spec/#{suite}/**/*_spec.rb"
    end
  end
end

namespace :acceptance do

  desc "Run a server for tests"
  task :server do
    require 'jenkins/plugin/specification'
    require 'jenkins/plugin/tools/server'

    require 'open-uri'
    require 'fileutils'

    def transitive_dependency(name, version)
      plugin = "work/plugins/#{name}.hpi"
      return if File.exists? plugin
      puts "Downloading #{name}-#{version} ..."
      file = open "http://mirrors.jenkins-ci.org/plugins/#{name}/#{version}/#{name}.hpi?for=ruby-plugin"
      FileUtils.cp file.path , plugin
    end

    spec = Jenkins::Plugin::Specification.load('jenkins-gitlab-hook.pluginspec')
    server = Jenkins::Plugin::Tools::Server.new(spec, 'work', nil, '8080')

    FileUtils.mkdir_p "work/plugins"
    transitive_dependency 'scm-api', '0.2'
    transitive_dependency 'git-client', '1.7.0'

    logfd, err = IO.pipe
    job = fork do
      $stdout.reopen File.new('/dev/null', 'w')
      $stderr.reopen err
      server.run!
    end
    Process.detach job

    until logfd.readline.include?("Jenkins is fully up and running")
    end

  end

end
