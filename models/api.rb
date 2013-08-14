require 'sinatra/base'

require_relative 'exceptions/bad_request_exception'
require_relative 'exceptions/configuration_exception'
require_relative 'exceptions/not_found_exception'
require_relative 'use_cases/process_delete_commit'
require_relative 'services/get_request_details'
require_relative 'services/get_jenkins_projects'
require_relative 'project'

include Java

java_import Java.java.util.logging.Logger
java_import Java.java.util.logging.Level

module GitlabWebHook
  class Api < Sinatra::Base
    LOGGER = Logger.getLogger(Api.class.name)

    get '/ping' do
      'Gitlab Web Hook is up and running :-)'
    end

    notify_commit = lambda do
      get_projects_to_process do |project|
        project.notify_commit
      end
    end
    get '/notify_commit', &notify_commit
    post '/notify_commit', &notify_commit

    build_now = lambda do
      get_projects_to_process do |project, details|
        project.build_now(details)
      end
    end
    get '/build_now', &build_now
    post '/build_now', &build_now

    private

    def get_projects_to_process
      details = GetRequestDetails.new.from(params, request)
      LOGGER.info("gitlab web hook triggered for repo url #{details.repository_url} and #{details.branch} branch")
      LOGGER.info("with payload: #{details.payload}")

      messages = []
      if details.is_delete_branch_commit?
        messages += ProcessDeleteCommit.new.with(details)
      else
        GetJenkinsProjects.new.matching(details).each do |project|
          messages << yield(project, details)
        end
      end
      LOGGER.info(messages.join("\n"))
      messages.join("<br/>")
    rescue BadRequestException => e
      LOGGER.warning(e.message)
      status 400
      e.message
    rescue NotFoundException => e
      LOGGER.warning(e.message)
      status 404
      e.message
    rescue Exception => e
      LOGGER.log(Level::SEVERE, e.message, e)
      status 500
      e.message
    end
  end
end
