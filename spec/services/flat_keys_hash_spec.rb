require 'spec_helper'

module GitlabWebHook
  describe FlatKeysHash do
    let (:payload) { JSON.parse(File.read('spec/fixtures/default_payload.json')) }
    let (:subject) { payload.extend(FlatKeysHash) }

    it 'keeps reference to first level keys' do
      expect(subject.to_flat_keys['after']).to eq('da1560886d4f094c3e6c9ef40349f7d38b5d27d7')
    end

    it 'preserves plain value type' do
      expect(subject.to_flat_keys['user_id']).to eq(4)
    end

    it 'exposes nested keys' do
      expect(subject.to_flat_keys[%w(repository name).join(FlatKeysHash::FLATTENED_KEYS_DELIMITER)]).to eq('Diaspora')
    end

    it 'exposes root' do
      repository = subject.to_flat_keys['repository']
      expect(repository.keys.count).to eq(4)
      expect(repository['url']).to eq('git@example.com:diaspora.git')
    end

    it 'indexes arrays' do
      expect(subject.to_flat_keys[%w(commits 1 id).join(FlatKeysHash::FLATTENED_KEYS_DELIMITER)]).to eq('da1560886d4f094c3e6c9ef40349f7d38b5d27d7')
    end

    it 'exposes nested array element' do
      commit = subject.to_flat_keys[%w(commits 0).join(FlatKeysHash::FLATTENED_KEYS_DELIMITER)]
      expect(commit.keys.count).to eq(5)
      expect(commit['message']).to eq('Update Catalan translation to e38cb41.')
    end

    it 'supports indefinite levels' do
      expect(subject.to_flat_keys[%w(commits 0 author email).join(FlatKeysHash::FLATTENED_KEYS_DELIMITER)]).to eq('jordi@softcatala.org')
    end

    it 'exposes nested root' do
      author = subject.to_flat_keys[%w(commits 1 author).join(FlatKeysHash::FLATTENED_KEYS_DELIMITER)]
      expect(author.keys.count).to eq(2)
      expect(author['email']).to eq('gitlabdev@dv6700.(none)')
    end
  end
end
