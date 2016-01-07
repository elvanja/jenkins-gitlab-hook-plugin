require 'jenkins/plugin/specification'
require 'jenkins/plugin/tools/server'

require 'net/http'
require 'rexml/document'

require 'tmpdir'
require 'fileutils'

class Jenkins::Server

  attr_reader :workdir
  attr_reader :job, :std, :log

  REQUIRED_CORE = '1.596.3'

  def initialize

    version = ENV['JENKINS_VERSION'] || REQUIRED_CORE

    FileUtils.mkdir_p 'vendor/bundle'
    warname = "vendor/bundle/jenkins-#{version}.war"

    download_war( version , warname )

    @workdir = Dir.mktmpdir 'work'

    spec = Jenkins::Plugin::Specification.load('jenkins-gitlab-hook.pluginspec')
    server = Jenkins::Plugin::Tools::Server.new(spec, workdir, warname, '8080')

    # Dependencies for git 2.0
    FileUtils.mkdir_p "#{workdir}/plugins"
    download_plugin 'scm-api', '0.1', "#{workdir}/plugins"
    download_plugin 'git-client', '1.4.4', "#{workdir}/plugins"
    download_plugin 'ssh-agent', '1.3', "#{workdir}/plugins"

    FileUtils.cp_r Dir.glob('work/*'), workdir

    @std, out = IO.pipe
    @log, err = IO.pipe
    @job = fork do
      $stdout.reopen out
      $stderr.reopen err
      ENV['JAVA_OPTS'] = "-XX:MaxPermSize=512m -Xms512m -Xmx1024m"
      server.run!
    end
    Process.detach job

    begin
      line = log.readline
      puts " -> #{line}"
    end until line.include?('Jenkins is fully up and running')


  end

  def kill
    Process.kill 'TERM', job
    dump log, ' -> '
    Process.waitpid job, Process::WNOHANG
  rescue Errno::ECHILD => e
  ensure
    Dir["#{workdir}/jobs/*/builds/?/log"].each do |file|
      puts
      puts "## #{file} ##"
      puts File.read(file)
    end
    Dir["#{workdir}/jobs/*/builds/?/build.xml"].each do |file|
      puts
      puts "## #{file} ##"
      puts File.read(file)
    end
    FileUtils.rm_rf workdir
  end

  def result(name, seq)
    sleep 30
    uri = URI "http://localhost:8080/job/#{name}/#{seq}/console"
    response = Net::HTTP.get uri
    doc = REXML::Document.new response
    log = doc.elements["//pre[contains(@class, 'console-output')]"].text
    # Explicit array conversion required for 1.9.3
    finished = log.lines.to_a.last.chomp
    finished.split.last
  end

  private

  def dump(instream, prefix='', outstream=$stdout)
    begin
      line = instream.readline
      outstream.puts "#{prefix}#{line}"
    end until instream.eof?
  end

end
