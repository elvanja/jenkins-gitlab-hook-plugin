require 'spec_helper'

require 'models/root_action_descriptor'

module GitlabWebHook
  describe ProcessMergeRequest do

    let (:payload) { JSON.parse(File.read('spec/fixtures/new_merge_request_payload.json')) }
    let (:details) { MergeRequestDetails.new(payload) }
    let (:jenkins_project) { double(AbstractProject, name: 'diaspora', matches?: false, merge_to?: false) }
    let (:get_jenkins_projects) { double(GetJenkinsProjects) }
    let (:create_project_for_branch) { double(for_merge: []) }

    before :each do
      expect(GetJenkinsProjects).to receive(:new).and_return( get_jenkins_projects )
      expect(CreateProjectForBranch).to receive(:new).and_return( create_project_for_branch )
    end

    context 'when merge request is unmergeable' do

      [ 'opened', 'reopened' ].each do |state|
        it "skips processing for state #{state}" do
          expect(details).to receive(:merge_status).twice.and_return( 'cannot_be_merged' )
          expect(details).to receive(:state).and_return( state )
          messages = subject.with(details)
          expect(messages[0]).to match('Skipping not ready merge request')
        end
      end

      it "keeps processing when closing" do
        expect(details).to receive(:merge_status).and_return( 'cannot_be_merged' )
        expect(details).to receive(:state).twice.and_return( 'closed' )
        expect(get_jenkins_projects).to receive(:matching_uri).and_return([jenkins_project])
        expect(jenkins_project).to receive(:matches?).and_return(true)
        expect(jenkins_project).to receive(:merge_to?).and_return(true)
        expect(jenkins_project).to receive(:delete)
        subject.with(details)
      end

    end

    context 'when merge request is mergeable' do

     before :each do
       expect(details).to receive(:merge_status).and_return( 'can_be_merged' )
       expect(get_jenkins_projects).to receive(:matching_uri).and_return([jenkins_project])
     end

     [ 'opened', 'reopened' ].each do |status|
      context "and status is #{status}" do
        before :each do
          expect(details).to receive(:state).and_return( status )
        end
        it 'and project already exists' do
          expect(jenkins_project).to receive(:matches?).and_return(true)
          expect(jenkins_project).to receive(:merge_to?).and_return(true)
          expect(BuildNow).to receive(:new).and_return(double(with:''))
          expect(create_project_for_branch).not_to receive(:for_merge)
          subject.with(details)
        end
        context 'and project does not exists' do
          let (:merge_project) { double(AbstractProject, name: 'diaspora-mr-branchname') }
          before :each do
            expect(jenkins_project).to receive(:matches?).and_return(true)
          end
          it 'and no candidate target project exists' do
            expect(create_project_for_branch).to receive(:for_merge).and_return([])
            expect(BuildNow).not_to receive(:new)
            subject.with(details)
          end
          it 'and target branch candidate exists' do
            expect(create_project_for_branch).to receive(:for_merge).and_return([merge_project])
            expect(BuildNow).to receive(:new).with(merge_project).and_return(double(with:''))
            subject.with(details)
          end
        end
      end
     end

     [ 'closed', 'merged' ].each do |status|
      context "and status is #{status}" do
        before :each do
          expect(details).to receive(:state).and_return( status )
          expect(create_project_for_branch).not_to receive(:for_merge)
        end
        it 'and project already exists' do
          expect(jenkins_project).to receive(:matches?).and_return(true)
          expect(jenkins_project).to receive(:merge_to?).and_return(true)
          expect(jenkins_project).to receive(:delete)
          subject.with(details)
        end
        it 'and only target_branch matches' do
          allow(jenkins_project).to receive(:merge_to?).and_return(true)
          expect(jenkins_project).not_to receive(:delete)
          subject.with(details)
        end
        it 'and only source_branch matches' do
          expect(jenkins_project).to receive(:matches?).and_return(true)
          expect(jenkins_project).not_to receive(:delete)
          subject.with(details)
        end
        it 'and project does not exists' do
          expect(jenkins_project).not_to receive(:delete)
          subject.with(details)
        end
      end
     end

    end

  end
end
