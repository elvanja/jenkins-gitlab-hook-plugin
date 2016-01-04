require 'net/http'
require 'open-uri'
require 'zip'

require 'fileutils'

def incoming_payload(filename, reponame, tempdir)
  uri = URI "http://localhost:8080/gitlab/build_now"
  req = Net::HTTP::Post.new(uri.request_uri, initheader = {'Content-Type' =>'application/json'})
  req.body = File.read("spec/fixtures/payloads/#{filename}.json") % { reponame: reponame, repodir: tempdir }
  http = Net::HTTP.new uri.host, uri.port
  response = Net::HTTP.start(uri.hostname, uri.port).request req
  sleep 10
end

def wait_for(url, xmlpath, waittime=60)
  count = waittime / 5
  begin
    visit url
    break if page.has_xpath? xmlpath
    sleep 5
  end until (count-=1).zero?
end

def wait_idle(waittime=60)
  sleep 5
  begin
    info = JSON.parse Net::HTTP.get URI "http://localhost:8080/computer/api/json"
    queue = JSON.parse Net::HTTP.get URI "http://localhost:8080/queue/api/json"
    break if info['busyExecutors'] == 0 and queue['items'].length == 0
    sleep 1
  end until (waittime-=1).zero?
end

def download_war(version, warname='jenkins.war')
  return if File.exists? warname
  puts "Downloading jenkins #{version} ..."
  if [ "1.532.3" , "1.554.3" , "1.565.3" ].include? version
    file = open "http://ks301030.kimsufi.com/war/#{version}/jenkins.war"
  else
    file = open "http://updates.jenkins-ci.org/download/war/#{version}/jenkins.war"
  end
  FileUtils.cp file.path, warname
end

def download_plugin(name, version, destdir='.')
  plugin = "#{destdir}/#{name}.hpi"
  return if File.exists? plugin
  puts "Downloading #{name}-#{version} ..."
  file = open "http://mirrors.jenkins-ci.org/plugins/#{name}/#{version}/#{name}.hpi?for=ruby-plugin"
  FileUtils.cp file.path, plugin
end

def extract_jar(zipfile, destdir='spec/plugins')
  FileUtils.mkdir_p "#{destdir}/WEB-INF/lib"
  Zip::File.open(zipfile) do |zipfile|
    zipfile.each do |entry|
      if entry.name.end_with? '.jar'
        outfile = "#{destdir}/#{entry.name}"
        entry.extract(outfile) unless File.exist? outfile
      end
    end
  end
end

def extract_classes(plugin, destdir='spec/plugins')
  FileUtils.mkdir_p "#{destdir}/WEB-INF/classes"
  Zip::File.open("#{plugin}.hpi") do |zipfile|
    zipfile.each do |entry|
      if entry.name.start_with? 'WEB-INF/classes'
        outfile = "#{destdir}/#{entry.name}"
        entry.extract(outfile) unless File.exist? outfile
      end
    end
  end
end

