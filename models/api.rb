require 'sinatra/base'
require 'json'

require_relative 'exceptions/bad_request_exception'
require_relative 'exceptions/configuration_exception'
require_relative 'exceptions/not_found_exception'
require_relative 'use_cases/process_commit'
require_relative 'use_cases/process_delete_commit'
require_relative 'use_cases/process_merge_request'
require_relative 'services/parse_request'

include Java

java_import Java.java.util.logging.Logger
java_import Java.java.util.logging.Level
java_import Java.org.jruby.exceptions.RaiseException

module GitlabWebHook
  class Api < Sinatra::Base
    get '/ping' do
      'Gitlab Web Hook is up and running :-)'
    end

    notify_commit = lambda do
      process_projects Proc.new { |project| NotifyCommit.new(project).call }
    end
    get '/notify_commit', &notify_commit
    post '/notify_commit', &notify_commit

    build_now = lambda do
      process_projects Proc.new { |project, details| BuildNow.new(project).with(details) }
    end
    get '/build_now', &build_now
    post '/build_now', &build_now

    error = lambda do
      unknown_route
    end
    get '/*', &error
    post '/*', &error

    private

    def process_projects(action)
      details = parse_request
      if details.classic?
        messages = details.delete_branch_commit? ? ProcessDeleteCommit.new.with(details) : ProcessCommit.new.with(details, action)
      else
        messages = ProcessMergeRequest.new.with(details)
      end
      logger.info(messages.join("\n"))
      messages.collect { |message| message.gsub("\n", '<br>') }.join("<br>")
    rescue BadRequestException => e
      logger.warning(e.message)
      status 400
      e.message.gsub("\n", '<br>')
    rescue NotFoundException => e
      logger.warning(e.message)
      status 404
      e.message.gsub("\n", '<br>')
    rescue => e
      # avoid method signature warnings
      severe = logger.java_method(:log, [Level, java.lang.String, java.lang.Throwable])
      severe.call(Level::SEVERE, e.message, RaiseException.new(e))
      status 500
      [e.message, '', 'Stack trace:', e.backtrace].flatten.join('<br>')
    end

    def parse_request
      ParseRequest.new.from(params, request).tap do |details|
      LOGGER.info("gitlab web hook triggered for repo url #{details.repository_url} and #{details.branch} branch") if details.classic?
        msgs = [
            'gitlab web hook triggered for',
            '   - with payload:',
            JSON.pretty_generate(details.payload)
        ]
        msgs.insert( 1,
            "   - repo url: #{details.repository_url}",
            "   - branch: #{details.branch}",
        ) if details.classic?
        logger.info(msgs.join("\n"))
      end
    end

    def unknown_route
      message = [
          "Don't know how to process '/#{params[:splat].first}'",
          'Use one of the following:',
          '   - /ping',
          '   - /notify_commit',
          '   - /build_now',
          'See https://github.com/elvanja/jenkins-gitlab-hook-plugin for details'
      ].join("\n")
      logger.warning(message)
      status 400
      message.gsub("\n", '<br>')
    end

    def logger
      @logger ||= Logger.getLogger(Api.class.name)
    end
  end
end
