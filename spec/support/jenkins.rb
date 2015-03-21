require 'jenkins/plugin/specification'
require 'jenkins/plugin/tools/server'

require 'open-uri'
require 'fileutils'

class Jenkins::Server

  attr_reader :warname, :job

  REQUIRED_CORE = '1.532.3'

  def initialize

    download_war( ENV['JENKINS_VERSION'] || REQUIRED_CORE )

    spec = Jenkins::Plugin::Specification.load('jenkins-gitlab-hook.pluginspec')
    server = Jenkins::Plugin::Tools::Server.new(spec, 'work', warname, '8080')

    transitive_dependency 'scm-api', '0.2'
    transitive_dependency 'git-client', '1.7.0'

    log, err = IO.pipe
    @job = fork do
      $stdout.reopen File.new('/dev/null', 'w')
      $stderr.reopen err
      server.run!
    end
    Process.detach job

    until log.readline.include?('Jenkins is fully up and running')
    end

  end

  def kill
    Process.kill 'TERM', job
    Process.wait job
  end

  private

  def download_war(version)
    @warname = "vendor/bundle/jenkins-#{version}.war"
    return if File.exists? warname
    puts "Downloading jenkins #{version} ..."
    FileUtils.mkdir_p 'vendor/bundle'
    file = open "http://updates.jenkins-ci.org/download/war/#{version}/jenkins.war"
    FileUtils.cp file.path, warname
  end

  def transitive_dependency(name, version)
    plugin = "work/plugins/#{name}.hpi"
    return if File.exists? plugin
    puts "Downloading #{name}-#{version} ..."
    FileUtils.mkdir_p 'work/plugins'
    file = open "http://mirrors.jenkins-ci.org/plugins/#{name}/#{version}/#{name}.hpi?for=ruby-plugin"
    FileUtils.cp file.path, plugin
  end

end
