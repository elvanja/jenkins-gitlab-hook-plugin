require 'rake'
require 'rspec/core/rake_task'

if RUBY_PLATFORM == 'java'
  task :default => :rspec
else
  task :default => :acceptance
end

desc "Run all RSpec code examples"
RSpec::Core::RakeTask.new(:rspec) do |t|
  t.pattern = "spec/*/**/*_spec.rb"
end

SPEC_SUITES = (Dir.entries('spec') - ['.', '..','fixtures']).select {|e| File.directory? "spec/#{e}" }
namespace :rspec do
  SPEC_SUITES.each do |suite|
    desc "Run #{suite} RSpec code examples"
    RSpec::Core::RakeTask.new(suite) do |t|
      t.pattern = "spec/#{suite}/**/*_spec.rb"
    end
  end
end

desc "Run acceptance tests"
task :acceptance do
  [ 'acceptance:server:start', 'acceptance:tests', 'acceptance:server:kill' ].each { |subtask| Rake::Task[subtask].invoke }
end

namespace :acceptance do

  namespace :server do

    desc "Run a server for tests"
    task :start do
      require 'jenkins/plugin/specification'
      require 'jenkins/plugin/tools/server'

      require 'open-uri'
      require 'fileutils'

      def transitive_dependency(name, version)
        plugin = "work/plugins/#{name}.hpi"
        return if File.exists? plugin
        puts "Downloading #{name}-#{version} ..."
        file = open "http://mirrors.jenkins-ci.org/plugins/#{name}/#{version}/#{name}.hpi?for=ruby-plugin"
        FileUtils.cp file.path, plugin
      end

      version = ENV['JENKINS_VERSION'] || '1.532.3'
      warname = "vendor/bundle/jenkins-#{version}.war"
      unless File.exists? warname
        puts "Downloading jenkins #{version} ..."
        FileUtils.mkdir_p 'vendor/bundle'
        file = open "http://updates.jenkins-ci.org/download/war/#{version}/jenkins.war"
        FileUtils.cp file.path, warname
      end

      spec = Jenkins::Plugin::Specification.load('jenkins-gitlab-hook.pluginspec')
      server = Jenkins::Plugin::Tools::Server.new(spec, 'work', warname, '8080')

      FileUtils.mkdir_p "work/plugins"
      transitive_dependency 'scm-api', '0.2'
      transitive_dependency 'git-client', '1.7.0'

      logfd, err = IO.pipe
      @job = fork do
        $stdout.reopen File.new('/dev/null', 'w')
        $stderr.reopen err
        server.run!
      end
      Process.detach @job

      until logfd.readline.include?("Jenkins is fully up and running")
      end

    end

    desc "Kill test server"
    task :kill do
      Process.kill 'TERM', @job
      Process.wait @job
    end

  end

  desc "Run acceptance RSpec examples"
  RSpec::Core::RakeTask.new(:tests) do |t|
    t.pattern = "spec/acceptance_spec.rb"
    t.rspec_opts = "--order default --format doc"
  end

end
