require 'sinatra/base'
require 'sinatra/json'

class GitLabMockup

  def initialize
    @std, out = IO.pipe
    @log, err = IO.pipe
    @server = fork do
      $stdout.reopen out
      $stderr.reopen err
      MyServer.run!
    end
    Process.detach @server
  end

  def kill
    Process.kill 'TERM', @server
    Process.waitpid @server, Process::WNOHANG
  rescue Errno::ECHILD => e
  end

  def dump(instream, prefix='', outstream=$stdout)
    begin
      line = instream.readline
      outstream.puts "#{prefix}#{line}"
    end until instream.eof?
  end

  class MyServer < Sinatra::Base

    helpers do

      def project_info(name)
        {
          'id' => 1,
          'name' => 'testrepo',
          'default_branch' => 'master',
          'http_url_to_repo' => "http://localhost/tmp/#{name}.git",
          'ssh_url_to_repo' => "localhost:/tmp/#{name}.git",
          'web_url' => "http://localhost/tmp/#{name}"
        }
      end

      def mr_response
        {
          'id' => 1, 'iid' => 1,
          'target_branch' => 'master',
          'source_branch' => 'feature/branch'
        }
      end
    end

    get "/api/v3/projects/search/:query" do
      json [ project_info(params['query']) ]
    end

    get "/api/v3/projects/:project_id/merge_requests" do
      json [ mr_response ]
    end

    post "/api/v3/projects/:project_id/repository/commits/:sha/comments" do
      json 'state' => 200
    end

  end

end

