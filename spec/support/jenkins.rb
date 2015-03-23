require 'jenkins/plugin/specification'
require 'jenkins/plugin/tools/server'

require 'tmpdir'
require 'open-uri'
require 'fileutils'

class Jenkins::Server

  attr_reader :warname, :workdir
  attr_reader :job, :std, :log

  REQUIRED_CORE = '1.532.3'

  def initialize

    download_war( ENV['JENKINS_VERSION'] || REQUIRED_CORE )
    @workdir = Dir.mktmpdir 'work'

    spec = Jenkins::Plugin::Specification.load('jenkins-gitlab-hook.pluginspec')
    server = Jenkins::Plugin::Tools::Server.new(spec, workdir, warname, '8080')

    # Actually required for git 2.1.0
    #transitive_dependency 'scm-api', '0.2', workdir
    #transitive_dependency 'git-client', '1.7.0', workdir

    FileUtils.cp_r Dir.glob('work/*'), workdir

    @std, out = IO.pipe
    @log, err = IO.pipe
    @job = fork do
      $stdout.reopen out
      $stderr.reopen err
      server.run!
    end
    Process.detach job

    until log.readline.include?('Jenkins is fully up and running')
    end

  end

  def kill
    Process.kill 'TERM', job
    Process.waitpid job, Process::WNOHANG
  rescue Errno::ECHILD => e
  ensure
    FileUtils.rm_rf workdir
  end

  private

  def dump(instream, prefix='', outstream=$stdout)
    begin
      line = instream.readline
      outstream.puts "#{prefix}#{line}"
    end until instream.eof?
  end

  def download_war(version)
    @warname = "vendor/bundle/jenkins-#{version}.war"
    return if File.exists? warname
    puts "Downloading jenkins #{version} ..."
    FileUtils.mkdir_p 'vendor/bundle'
    file = open "http://updates.jenkins-ci.org/download/war/#{version}/jenkins.war"
    FileUtils.cp file.path, warname
  end

  def transitive_dependency(name, version, work='work')
    plugin = "#{work}/plugins/#{name}.hpi"
    return if File.exists? plugin
    puts "Downloading #{name}-#{version} ..."
    FileUtils.mkdir_p "#{work}/plugins"
    file = open "http://mirrors.jenkins-ci.org/plugins/#{name}/#{version}/#{name}.hpi?for=ruby-plugin"
    FileUtils.cp file.path, plugin
  end

end
