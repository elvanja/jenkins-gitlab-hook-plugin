require 'spec_helper'

module GitlabWebHook
  describe AbstractDetails do

    it '#repository_url is abstract' do
      expect { subject.repository_url }.to raise_exception(NameError)
    end

    it '#repository_name is abstract' do
      expect { subject.repository_name }.to raise_exception(NameError)
    end

    it '#repository_homepage is abstract' do
      expect { subject.repository_homepage }.to raise_exception(NameError)
    end

    it '#branch is abstract' do
      expect { subject.branch }.to raise_exception(NameError)
    end

    it 'makes branch safe' do
      allow(subject).to receive(:branch) { 'feature/cool' }
      expect(subject.safe_branch).to eq('feature_cool')
    end

    it '#payload returns empty hash' do
      expect(subject.payload).to eq({})
    end

  end
end
