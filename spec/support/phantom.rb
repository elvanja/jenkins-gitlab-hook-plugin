require 'fileutils'

def phantom(version='1.9.2')

  exe = `which phantomjs 2>/dev/null`.chomp
  return exe unless exe.empty?

  arch , os = RUBY_PLATFORM.split '-'
  name = "phantomjs-#{version}-#{os}-#{arch}"
  url = "http://phantomjs.googlecode.com/files/#{name}.tar.bz2"

  File.join(Bundler.user_bundle_path, name, 'bin/phantomjs').tap do |exe|
    unless File.exists? exe
      FileUtils.mkdir_p Bundler.user_bundle_path
      Dir.chdir(Bundler.user_bundle_path) do
        puts "Downloading phantomjs #{version} ..."
        system("curl -s #{url} | tar -jx")
      end
    end
  end
end

