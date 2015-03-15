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

    spec = Jenkins::Plugin::Specification.load('jenkins-gitlab-hook.pluginspec')
    server = Jenkins::Plugin::Tools::Server.new(spec, 'work', nil, '8080')

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
