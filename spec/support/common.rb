require 'net/http'

def incoming_payload(filename, tempdir)
  uri = URI "http://localhost:8080/gitlab/build_now"
  req = Net::HTTP::Post.new(uri, initheader = {'Content-Type' =>'application/json'})
  req.body = File.read("spec/fixtures/payloads/#{filename}.json") % { repodir: tempdir }
  http = Net::HTTP.new uri.host, uri.port
  response = Net::HTTP.start(uri.hostname, uri.port).request req
end

