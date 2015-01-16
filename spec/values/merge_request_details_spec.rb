require 'spec_helper'

module GitlabWebHook
  describe MergeRequestDetails do

    let (:payload) { JSON.parse(File.read('spec/fixtures/merge_request_payload.json')) }
    let (:subject) { MergeRequestDetails.new(payload) }

    context 'when initializing' do
      it 'requires payload data' do
        expect { MergeRequestDetails.new(nil) }.to raise_exception(ArgumentError)
      end
      it 'raise exception for cross-repo merge requests' do
        payload['object_attributes']['target_project_id'] = '15'
        expect { MergeRequestDetails.new(payload) }.to raise_exception(BadRequestException)
      end
    end

    it '#classic? is true' do
      expect(subject.classic?).to eq(false)
    end

    it '#kind is merge request' do
      expect(subject.kind).to eq('merge_request')
    end

    context '#project_id' do
      it 'parsed from payload' do
        expect(subject.project_id).to eq('14')
      end

      it 'returns empty when no source project found' do
        payload['object_attributes'].delete('source_project_id')
        payload['object_attributes'].delete('target_project_id')
        expect(subject.project_id).to eq('')
      end
    end

    context do
      before :each do
        expect(subject).to receive(:get_project_details).and_return( {
             'name' => 'diaspora' ,
             'web_url' => 'http://localhost/peronospora',
             'ssh_url_to_repo' => 'git@localhost:peronospora.git' } )
      end

      it '#repository_url returns ssh url for repository' do
        expect(subject.repository_url).to eq('git@localhost:peronospora.git')
      end

      it '#repository_name returns repository name' do
        expect(subject.repository_name).to eq('diaspora')
      end

      it '#repository_homepage returns homepage for repository' do
        expect(subject.repository_homepage).to eq('http://localhost/peronospora')
      end

    end

    context '#branch' do
      it 'returns source branch' do
        expect(subject.branch).to eq('ms-viewport')
      end

      it 'returns empty when no source branch found' do
        payload['object_attributes'].delete('source_branch')
        expect(subject.branch).to eq('')
      end
    end

    context '#target_project_id' do
      it 'parsed from payload' do
        expect(subject.target_project_id).to eq('14')
      end

      it 'returns empty when no target project found' do
        payload['object_attributes'].delete('source_project_id')
        payload['object_attributes'].delete('target_project_id')
        expect(subject.target_project_id).to eq('')
      end
    end

    context '#target_branch' do
      it 'parsed from payload' do
        expect(subject.target_branch).to eq('master')
      end

      it 'returns empty when no target branch found' do
        payload['object_attributes'].delete('target_branch')
        expect(subject.target_branch).to eq('')
      end
    end

    context '#state' do
      it 'parsed from payload' do
        expect(subject.state).to eq('opened')
      end

      it 'returns empty when no state data found' do
        payload['object_attributes'].delete('state')
        expect(subject.state).to eq('')
      end
    end

    context '#merge_status' do
      it 'parsed from payload' do
        expect(subject.merge_status).to eq('unchecked')
      end

      it 'returns empty when no merge status data found' do
        payload['object_attributes'].delete('merge_status')
        expect(subject.merge_status).to eq('')
      end
    end

    context 'new payload for merge requests' do

      let (:payload) { JSON.parse(File.read('spec/fixtures/new_merge_request_payload.json')) }
      let (:subject) { MergeRequestDetails.new(payload) }

      it '#repository_url returns ssh url for repository' do
        expect(subject.repository_url).to eq('git@example.com:awesome_space/awesome_project.git')
      end

      it '#repository_name returns repository name' do
        expect(subject.repository_name).to eq('awesome_project')
      end

      it '#repository_homepage returns homepage for repository' do
        expect(subject.repository_homepage).to eq('http://example.com/awesome_space/awesome_project.git')
      end

    end

  end
end
