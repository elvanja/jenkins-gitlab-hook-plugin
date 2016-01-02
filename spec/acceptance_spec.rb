require 'spec_helper'

require 'tmpdir'
require 'fileutils'
require 'pathname'

Autologin.enable

feature 'GitLab WebHook' do

  testrepodir = Dir.mktmpdir [ 'testrepo' , '.git' ]
  tagsrepodir = Dir.mktmpdir [ 'tagsrepo' , '.git' ]
  xtrarepodir = Dir.mktmpdir [ 'xtrarepo' , '.git' ]

  before(:all) do
    FileUtils.cp_r Dir.glob("spec/fixtures/testrepo.git/*"), testrepodir
    FileUtils.cp_r Dir.glob("spec/fixtures/testrepo.git/*"), tagsrepodir
    File.open('work/jobs/tagbuilder/config.xml', 'w') do |outfd|
      infd = File.open 'work/jobs/tagbuilder/config.xml.erb'
      outfd.write( infd.read % { tagsrepodir: tagsrepodir } )
      infd.close
    end
    FileUtils.cp_r Dir.glob("spec/fixtures/testrepo.git/*"), xtrarepodir
    File.open('work/jobs/subdirjob/config.xml', 'w') do |outfd|
      outfd.write File.read('work/jobs/subdirjob/config.xml.erb') % { xtrarepodir: xtrarepodir }
    end
    @server = Jenkins::Server.new
    @gitlab = GitLabMockup.new Pathname.new(testrepodir).basename('.git').to_s
  end

  after(:all) do
    FileUtils.remove_dir xtrarepodir
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

    scenario 'Does not create project for tag' do
      incoming_payload 'tag', 'testrepo', testrepodir
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
      expect(@server.result('testrepo', 1)).to eq 'SUCCESS'
      expect(@gitlab.last).to eq '/comment/e3719eaab95642a63e90da0b9b23de0c9d384785'
    end

    scenario 'Does nothing for tags' do
      incoming_payload 'tag', 'testrepo', testrepodir
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
      expect(@server.result('testrepo', 2)).to eq 'SUCCESS'
      expect(@gitlab.last).to eq '/comment/6957dc21ae95f0c70931517841a9eb461f94548c'
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
      expect(@server.result('testrepo_feature_branch', 1)).to eq 'SUCCESS'
      expect(@gitlab.last).to eq '/comment/80a89e1156d5d7e9471c245ccaeafb7bcb49c0a5'
    end

    scenario 'Builds a push to feature branch' do
      File.write("#{testrepodir}/refs/heads/feature/branch", 'ba46b858929aec55a84a9cb044e988d5d347b8de')
      incoming_payload 'branch_push', 'testrepo', testrepodir
      wait_for '/job/testrepo_feature_branch', "//a[@href='/job/testrepo_feature_branch/2/']"
      expect(page).to have_xpath("//a[@href='/job/testrepo_feature_branch/2/']")
      wait_idle
      expect(@server.result('testrepo_feature_branch', 2)).to eq 'SUCCESS'
      expect(@gitlab.last).to eq '/comment/ba46b858929aec55a84a9cb044e988d5d347b8de'
    end

    scenario 'Branch removal' do
      incoming_payload 'branch_deletion', 'testrepo', testrepodir
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
      expect(@server.result('tagbuilder', 1)).to eq 'SUCCESS'
    end

    scenario 'Does not process templates when a tag project exists' do
      incoming_payload 'first_push', 'tagsrepo', tagsrepodir
      visit '/'
      pending 'unimplemented fix'
      expect(page).not_to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_tagsrepo_master']")
    end

  end

  feature 'Legacy (<7.4.3) merge request handling' do

    scenario 'Finds cloneable project' do
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo']")
    end

    scenario 'Create project with merge request' do
      incoming_payload 'legacy/merge_request', 'testrepo', testrepodir
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo-mr-feature_branch']")
      wait_idle
      expect(@server.result('testrepo-mr-feature_branch', 1)).to eq 'SUCCESS'
      expect(@gitlab.last).to eq '/mr_comment/1'
    end

    scenario 'Remove project once merged' do
      incoming_payload 'legacy/accept_merge_request', 'testrepo', testrepodir
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
      incoming_payload 'merge_request', 'testrepo', testrepodir
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo-mr-feature_branch']")
      wait_idle
      expect(@server.result('testrepo-mr-feature_branch', 1)).to eq 'SUCCESS'
      expect(@gitlab.last).to eq '/mr_comment/1'
    end

    scenario 'Remove project once merged' do
      incoming_payload 'accept_merge_request', 'testrepo', testrepodir
      visit '/'
      expect(page).not_to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo-mr-feature_branch']")
      wait_idle
    end

  end

  feature 'Report commit status' do

    scenario 'Enables build status report' do
      page.driver.headers = { 'Accept-Language' => 'en' }
      visit '/configure'
      check '_.commit_status'
      click_button 'Apply'
      sleep 5
    end

    scenario 'Post status for push' do
      incoming_payload 'master_push', 'testrepo', testrepodir
      wait_for '/job/testrepo', "//a[@href='/job/testrepo/3/']"
      expect(page).to have_xpath("//a[@href='/job/testrepo/3/']")
      wait_idle
      expect(@server.result('testrepo', 3)).to eq 'SUCCESS'
      expect(@gitlab.last).to eq '/status/6957dc21ae95f0c70931517841a9eb461f94548c'
    end

    scenario 'Post status to source branch commit' do
      incoming_payload 'merge_request', 'testrepo', testrepodir
      visit '/'
      expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_testrepo-mr-feature_branch']")
      wait_idle
      expect(@server.result('testrepo-mr-feature_branch', 1)).to eq 'SUCCESS'
      expect(@gitlab.last).to eq '/status/ba46b858929aec55a84a9cb044e988d5d347b8de'
    end

    feature 'when cloning to subdir' do

      scenario 'Post status for push' do
        incoming_payload 'master_push', 'subdirjob', xtrarepodir
        wait_for '/job/subdirjob', "//a[@href='/job/subdirjob/1/']"
        expect(page).to have_xpath("//a[@href='/job/subdirjob/1/']")
        wait_idle
        expect(@server.result('subdirjob', 1)).to eq 'SUCCESS'
        expect(@gitlab.last).to eq '/status/e3719eaab95642a63e90da0b9b23de0c9d384785'
      end

      scenario 'Post status to source branch commit' do
        File.write("#{xtrarepodir}/refs/heads/master", '6957dc21ae95f0c70931517841a9eb461f94548c')
        File.write("#{xtrarepodir}/refs/heads/feature/branch", 'ba46b858929aec55a84a9cb044e988d5d347b8de')
        incoming_payload 'merge_request', 'subdirjob', xtrarepodir
        visit '/'
        expect(page).to have_xpath("//table[@id='projectstatus']/tbody/tr[@id='job_subdirjob-mr-feature_branch']")
        wait_idle
        expect(@server.result('subdirjob-mr-feature_branch', 1)).to eq 'SUCCESS'
        expect(@gitlab.last).to eq '/status/ba46b858929aec55a84a9cb044e988d5d347b8de'
      end

    end

  end

end

