# Load all bundled gems
pwd = File.expand_path('..', __FILE__)
Dir["#{pwd}/../gems/*/lib"].each do |path|
  $LOAD_PATH.unshift path
end
