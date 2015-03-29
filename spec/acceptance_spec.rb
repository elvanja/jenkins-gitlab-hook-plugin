require 'spec_helper'

require 'tmpdir'
require 'fileutils'

Autologin.enable

feature 'GitLab WebHook' do

  testrepodir = Dir.mktmpdir [ 'testrepo' , '.git' ]
  tagsrepodir = Dir.mktmpdir [ 'tagsrepo' , '.git' ]

  before(:all) do
    FileUtils.cp_r Dir.glob("spec/fixtures/testrepo.git/*"), testrepodir
    FileUtils.cp_r Dir.glob("spec/fixtures/testrepo.git/*"), tagsrepodir
    File.open('work/jobs/tagbuilder/config.xml', 'w') do |outfd|
      infd = File.open 'work/jobs/tagbuilder/config.xml.erb'
      outfd.write( infd.read % { tagsrepodir: tagsrepodir } )
      infd.close
    end
    @server = Jenkins::Server.new
  end

  after(:all) do
    FileUtils.remove_dir tagsrepodir
    FileUtils.remove_dir testrepodir
    @server.kill
  end

  # Fixture payloads generated on gitlab 7.2.2

  feature 'Template based creation' do

    scenario 'Finds fallback template' do
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_simplejob']")
    end

    scenario 'Does not create project for tag' do
      incoming_payload 'tag', 'testrepo', testrepodir
      sleep 5
      visit '/'
      expect(page).not_to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo_tag1']")
      expect(page).not_to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo_']")
      expect(page).not_to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo']")
    end

    scenario 'Creates project from template' do
      incoming_payload 'first_push', 'testrepo', testrepodir
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo']")
      wait_idle
    end

    scenario 'Does nothing for tags' do
      incoming_payload 'tag', 'testrepo', testrepodir
      sleep 5
      visit '/'
      expect(page).not_to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo_tag1']")
      expect(page).not_to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo_']")
    end

    scenario 'Builds a push to master branch' do
      File.write("#{testrepodir}/refs/heads/master", '6957dc21ae95f0c70931517841a9eb461f94548c')
      incoming_payload 'master_push', 'testrepo', testrepodir
      wait_for '/job/testrepo', "//a[@href='/job/testrepo/2/']"
      expect(page).to have_xpath("//a[@href='/job/testrepo/2/']")
      wait_idle
    end

  end

  feature 'Automatic project creation' do

    scenario 'Finds cloneable project' do
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo']")
    end

    scenario 'Creates project for new branch' do
      incoming_payload 'branch_creation', 'testrepo', testrepodir
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo_feature_branch']")
      wait_idle
    end

    scenario 'Builds a push to feature branch' do
      File.write("#{testrepodir}/refs/heads/feature/branch", 'ba46b858929aec55a84a9cb044e988d5d347b8de')
      incoming_payload 'branch_push', 'testrepo', testrepodir
      wait_for '/job/testrepo_feature_branch', "//a[@href='/job/testrepo_feature_branch/2/']"
      expect(page).to have_xpath("//a[@href='/job/testrepo_feature_branch/2/']")
      wait_idle
    end

    scenario 'Branch removal' do
      incoming_payload 'branch_deletion', 'testrepo', testrepodir
      sleep 5
      visit '/'
      expect(page).not_to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo_feature_branch']")
    end

  end

  feature 'Tag building' do

    scenario 'Trigger build for tags' do
      incoming_payload 'tag', 'tagsrepo', tagsrepodir
      wait_for '/job/tagbuilder', "//a[@href='/job/tagbuilder/1/']"
      expect(page).to have_xpath("//a[@href='/job/tagbuilder/1/']")
      wait_idle
    end

    scenario 'Does not process templates when a tag project exists' do
      incoming_payload 'first_push', 'tagsrepo', tagsrepodir
      sleep 5
      visit '/'
      pending 'unimplemented fix'
      expect(page).not_to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_tagsrepo_master']")
    end

  end

  # MR payloads from gitlab 7.4.3, until a proper mockup is developed

  feature 'Merge request handling' do

    scenario 'Finds cloneable project' do
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo']")
    end

    scenario 'Create project with merge request' do
      incoming_payload 'merge_request', 'testrepo', testrepodir
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo-mr-feature_branch']")
      wait_idle
    end

    scenario 'Remove project once merged' do
      incoming_payload 'accept_merge_request', 'testrepo', testrepodir
      sleep 5
      visit '/'
      expect(page).not_to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo-mr-feature_branch']")
      wait_idle
    end

  end

end

