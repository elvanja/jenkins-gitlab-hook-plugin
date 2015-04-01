require 'sinatra/base'
require 'sinatra/json'

class GitLabMockup

  def initialize(name)
    # We actully hide whole stderr, not only sinatra, but
    # that's better than keep the noise added by request tracing
    @log, err = IO.pipe
    @server = Thread.fork do
      $stderr.reopen err
      MyServer.start name
    end
  end

  def last
    MyServer.last
  end

  def kill
    @server.kill
    @server.join
  end

  def dump(instream, prefix='', outstream=$stdout)
    begin
      line = instream.readline
      outstream.puts "#{prefix}#{line}"
    end until instream.eof?
  end

  class MyServer < Sinatra::Base

    class << self

      def last
        @@last
      end

      def last=(value)
        @@last = value
      end

      def start(name)
        @@name = name
        run!
      end

    end

    helpers do

      def author
        {
            "id" => 1,
            "name" => "root",
            "username" => "root"
        }
      end

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

    get "/api/v3/projects/:project_id" do
      json project_info(@@name)
    end

    get "/api/v3/projects/search/:query" do
      json [ project_info(params['query']) ]
    end

    get "/api/v3/projects/:project_id/merge_requests" do
      json [ mr_response ]
    end

    post "/api/v3/projects/:project_id/merge_request/:mr_id/comments" do
      self.class.last = "/mr_comment/#{params[:mr_id]}"
      json author: author , note: request.body.string
    end

    post "/api/v3/projects/:project_id/repository/commits/:sha/comments" do
      self.class.last = "/comment/#{params[:sha]}"
      json author: author , note: request.body.string
    end

    post "/api/v3/projects/:project_id/repository/commits/:sha/status" do
      self.class.last = "/status/#{params[:sha]}"
      json state: params[:state] , target_url: params[:target_url]
    end

  end

end

