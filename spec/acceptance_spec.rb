require 'spec_helper'

require 'tmpdir'
require 'fileutils'
require 'pathname'

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
    @gitlab = GitLabMockup.new Pathname.new(testrepodir).basename('.git').to_s
  end

  after(:all) do
    FileUtils.remove_dir tagsrepodir
    FileUtils.remove_dir testrepodir
    @server.kill
    @gitlab.kill
  end

  # Fixture payloads generated on gitlab 7.2.2

  feature 'Template based creation' do

    scenario 'Finds fallback template' do
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_simplejob']")
    end

    scenario 'Creates project from template' do
      incoming_payload 'first_push', testrepodir
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo']")
      wait_idle
    end

    scenario 'Does nothing for tags' do
      incoming_payload 'tag', testrepodir
      sleep 5
      visit '/job/testrepo'
      expect(page).not_to have_xpath("//a[@href='/job/testrepo/2/']")
    end

    scenario 'Builds a push to master branch' do
      File.write("#{testrepodir}/refs/heads/master", '6957dc21ae95f0c70931517841a9eb461f94548c')
      incoming_payload 'master_push', testrepodir
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
      incoming_payload 'branch_creation', testrepodir
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo_feature_branch']")
      wait_idle
    end

    scenario 'Builds a push to feature branch' do
      File.write("#{testrepodir}/refs/heads/feature/branch", 'ba46b858929aec55a84a9cb044e988d5d347b8de')
      incoming_payload 'branch_push', testrepodir
      wait_for '/job/testrepo_feature_branch', "//a[@href='/job/testrepo_feature_branch/2/']"
      expect(page).to have_xpath("//a[@href='/job/testrepo_feature_branch/2/']")
      wait_idle
    end

    scenario 'Branch removal' do
      incoming_payload 'branch_deletion', testrepodir
      sleep 5
      visit '/'
      expect(page).not_to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo_feature_branch']")
    end

  end

  feature 'Tag building' do

    scenario 'Trigger build for tags' do
      incoming_payload 'tag', tagsrepodir
      wait_for '/job/tagbuilder', "//a[@href='/job/tagbuilder/1/']"
      expect(page).to have_xpath("//a[@href='/job/tagbuilder/1/']")
      wait_idle
    end

  end

  feature 'Legacy (<7.4.3) merge request handling' do

    scenario 'Finds cloneable project' do
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo']")
    end

    scenario 'Create project with merge request' do
      incoming_payload 'legacy/merge_request', testrepodir
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo-mr-feature_branch']")
      wait_idle
    end

    scenario 'Remove project once merged' do
      incoming_payload 'legacy/accept_merge_request', testrepodir
      sleep 5
      visit '/'
      expect(page).not_to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo-mr-feature_branch']")
      wait_idle
    end

  end

  feature 'Merge request handling' do

    scenario 'Finds cloneable project' do
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo']")
    end

    scenario 'Create project with merge request' do
      incoming_payload 'merge_request', testrepodir
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo-mr-feature_branch']")
      wait_idle
    end

    scenario 'Remove project once merged' do
      incoming_payload 'accept_merge_request', testrepodir
      sleep 5
      visit '/'
      expect(page).not_to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo-mr-feature_branch']")
      wait_idle
    end

  end

end

