# dependencies
require 'json'
require 'ostruct'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.expand_path('../support/**/*.rb', __FILE__)].each { |f| require f }

# Requires all extra / autoload paths
# Recommendation: do not rely on autoload for domain objects, use this just for specs
unless defined?(Rails)
  %W(
    models/exceptions
    models/values
    models/services
    models/use_cases
  ).each do |autoload_path|
    Dir[File.expand_path("../../#{autoload_path}/**/*.rb", __FILE__)].each { |f| require f }
  end
end

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
end