require 'support/env'

require 'tmpdir'
require 'fileutils'
require 'net/http'

feature 'GitLab WebHook' do

  testrepodir = Dir.mktmpdir [ 'testrepo' , '.git' ]

  before(:all) do
    FileUtils.cp_r Dir.glob("spec/fixtures/testrepo.git/*"), testrepodir
  end

  after(:all) do
    FileUtils.remove_dir testrepodir
    FileUtils.rm_rf Dir.glob('work/jobs/testrepo*')
  end

  # Fixture payloads generated on gitlab 7.2.2

  feature 'Template based creation' do

    scenario 'Finds fallback template' do
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_simplejob']")
    end

    scenario 'Creates project from template' do
      uri = URI "http://localhost:8080/gitlab/build_now"
      req = Net::HTTP::Post.new(uri, initheader = {'Content-Type' =>'application/json'})
      req.body = File.read("spec/fixtures/payloads/first_push.json") % { repodir: testrepodir }
      http = Net::HTTP.new uri.host, uri.port
      response = Net::HTTP.start(uri.hostname, uri.port).request req
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo']")
    end

  end

end

