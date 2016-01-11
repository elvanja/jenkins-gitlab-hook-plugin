require 'spec_helper'

module GitlabWebHook
  describe RequestDetails do
    context 'with validation' do
      before :each do
        allow(subject).to receive(:kind) { 'webhook' }
      end

      it 'is valid when repository url is present' do
        allow(subject).to receive(:repository_url) { 'http://repo.url' }
        expect(subject.valid?).to be
      end

      it 'is not valid when repository url is missing' do
        [nil, '', "  \n  "].each do |repository_url|
          allow(subject).to receive(:repository_url) { repository_url }
          expect(subject.valid?).not_to be
        end
      end
    end

    context 'with repository uri' do
      it 'returns uri regardless of repository url' do
        ['http://repo.url', nil, '', '  \n  '].each do |repository_url|
          allow(subject).to receive(:repository_url) { repository_url }
          expect(subject.repository_uri).to be_kind_of(RepositoryUri)
        end
      end
    end

    context 'with full branch name' do
      it 'expects to implemented in concrete implementation' do
        expect { subject.full_branch_reference }.to raise_exception(NameError)
      end
    end

    context 'with branch' do
      it 'extracts branch name from payload' do
        allow(subject).to receive(:full_branch_reference) { 'refs/heads/master' }
        expect(subject.branch).to eq('master')
      end

      it 'returns empty branch name when no branch reference data found' do
        allow(subject).to receive(:full_branch_reference) { nil }
        expect(subject.branch).to eq('')
      end

      it 'makes branch safe' do
        allow(subject).to receive(:full_branch_reference) { 'refs/heads/feature/cool' }
        expect(subject.safe_branch).to eq('feature_cool')
      end

      it 'returns nil when no payload present' do
        allow(subject).to receive(:full_branch_reference) { nil }
        expect(subject.branch).to eq('')
      end

      it 'removes refs, heads and tags from result' do
        refs = ['ref', 'refs']
        heads = ['head', 'heads']
        refs.product(heads).each do |combination|
          allow(subject).to receive(:full_branch_reference) { "#{combination.join('/')}/master" }
          expect(subject.branch).to eq('master')
        end
      end

      it 'detects non refs and non heads' do
        ['refref', 'headhead', 'tagtag'].each do |ref|
          allow(subject).to receive(:full_branch_reference) { ref }
          expect(subject.branch).to eq(ref)
        end
      end

      it 'returns branch name' do
        allow(subject).to receive(:full_branch_reference) { 'refs/heads/master' }
        expect(subject.branch).to eq('master')
      end

      it 'respects nested branches' do
        allow(subject).to receive(:full_branch_reference) { 'refs/heads/feature/new_hot_feature' }
        expect(subject.branch).to eq('feature/new_hot_feature')
      end

      it 'returns no tagname' do
        allow(subject).to receive(:full_branch_reference) { 'refs/heads/master' }
        expect(subject.tagname).to eq(nil)
      end
    end

    context 'with tag' do
      it 'extracts tag name from payload' do
        allow(subject).to receive(:full_branch_reference) { 'refs/tags/v1.0.0' }
        expect(subject.tagname).to eq('v1.0.0')
      end
    end

    context 'with delete branch commit' do
      it 'expects to implemented in concrete implementation' do
        expect { subject.repository_delete_branch_commit? }.to raise_exception(NameError)
      end
    end

    context 'with commits' do
      it 'defaults to empty array' do
        expect(subject.commits).to eq([])
      end

      it 'requires it to be an array' do
        allow(subject).to receive(:get_commits) { 'invalid commits' }
        expect { subject.commits }.to raise_exception(ArgumentError)
      end
    end

    context 'with commits count' do
      it 'returns commits size' do
        allow(subject).to receive(:commits) { [double, double, double] }
        expect(subject.commits_count).to eq(3)
      end

      it 'defaults to 0 when no commits present' do
        allow(subject).to receive(:commits) { nil }
        expect(subject.commits_count).to eq(0)
      end
    end

    context 'with payload' do
      it 'defaults to empty hash' do
        expect(subject.payload).to eq({})
      end

      it 'requires it to be a hash' do
        allow(subject).to receive(:get_payload) { 'invalid payload' }
        expect { subject.payload }.to raise_exception(ArgumentError)
      end
    end

    context 'with flat payload' do
      details = {
        repository_url: 'git@example.com:diaspora/diaspora.git',
        repository_name: 'Diaspora',
        repository_homepage: 'http://example.com/diaspora/diaspora',
        full_branch_reference: 'refs/heads/master',
        branch: 'master'
      }

      let(:payload) { JSON.parse(File.read('spec/fixtures/default_payload.json')) }

      before(:each) do
        details.each { |detail, value| allow(subject).to receive(detail) { value } }
        allow(subject).to receive(:get_payload) { payload }
      end

      it 'returns flattened payload' do
        expect(subject.flat_payload[%w(repository name).join(FlatKeysHash::FLATTENED_KEYS_DELIMITER)]).to eq('Diaspora')
      end

      details.each do |detail, value|
        it "appends :#{detail} from details" do
          expect(subject.flat_payload[detail.to_s]).to eq(value)
        end
      end

      it 'tagname absent' do
        expect(subject.flat_payload.keys).not_to include( 'tagname' )
      end

      it 'memoizes flattened payload' do
        expect(payload).to receive(:to_flat_keys).once.and_return({})
        10.times { subject.flat_payload }
      end

      it 'returns tagname if present' do
        allow(subject).to receive('full_branch_reference') { 'refs/tags/v1.0.0' }
        expect(subject.flat_payload['tagname']).to eq('v1.0.0')
      end
    end
  end
end
