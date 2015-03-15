require 'capybara/rspec'
require 'capybara/poltergeist'

Capybara.default_driver = :poltergeist
Capybara.javascript_driver = :poltergeist
Capybara.register_driver :poltergeist do |app|
  opts = {
    :phantomjs => `which phantomjs`.chomp
  }
  Capybara::Poltergeist::Driver.new(app, opts)
end

Capybara.configure do |c|
  c.app = proc{}
  c.app_host = "http://localhost:8080"
  c.run_server = false
end

