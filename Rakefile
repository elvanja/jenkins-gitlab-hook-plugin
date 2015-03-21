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
RSpec::Core::RakeTask.new(:acceptance) do |t|
  t.pattern = "spec/acceptance_spec.rb"
  t.rspec_opts = "--order default --format doc"
end

