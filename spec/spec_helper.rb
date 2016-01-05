# test dependencies
require 'json'
require 'support/common'

REQUIRED_CORE = '1.554.3'

# java dependencies
java_libs = Dir["spec/lib/**/*.jar"]

# the rest of the application
model_files = %W(models/exceptions models/values models/services models/use_cases)

if RUBY_PLATFORM == 'java'

  # jenkins core libraries
  download_war( ENV['JENKINS_VERSION'] || REQUIRED_CORE )
  extract_jar 'jenkins.war', 'spec/war'
  java_libs = java_libs + Dir["spec/war/winstone.jar", "spec/war/WEB-INF/lib/*.jar"]

  # required plugins
  download_plugin 'git', '2.0'
  download_plugin 'git-client', '1.4.4'
  download_plugin 'multiple-scms', '0.4'
  download_plugin 'matrix-project', '1.2'
  download_plugin 'credentials', '1.18'
  ['git', 'git-client', 'multiple-scms', 'matrix-project', 'credentials'].each{ |plugin| extract_jar "#{plugin}.hpi" }
  java_libs = java_libs + Dir["spec/plugins/WEB-INF/lib/*.jar"]
  # Some old versions do not have a jarfile with their own classes
  ['git', 'git-client', 'credentials'].each{ |plugin| extract_classes plugin }
  $CLASSPATH << 'spec/plugins/WEB-INF/classes'

  java_libs.each do |jar|
    require jar
  end

  model_files.each do |autoload_path|
    Dir[File.expand_path("../../#{autoload_path}/**/*.rb", __FILE__)].each { |f| require f }
  end

end

# supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.expand_path('../support/**/*.rb', __FILE__)].each { |f| require f }

RSpec.configure do |config|
  # disable should syntax, it wil become obsolete in future RSpec releases
  # http://myronmars.to/n/dev-blog/2012/06/rspecs-new-expectation-syntax
  config.expect_with :rspec do |c|
    c.syntax = [:expect]
  end

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"

  config.raise_errors_for_deprecations!
end
