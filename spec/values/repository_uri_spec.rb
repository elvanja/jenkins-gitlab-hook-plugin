require 'spec_helper'

module GitlabWebHook
  describe RepositoryUri do
    let(:subject) { RepositoryUri.new('http://localhost/diaspora') }

    context 'with attributes' do
      it 'has url' do
        expect(subject.url).to eq('http://localhost/diaspora')
      end

      it 'has host' do
        expect(subject.host).to eq('localhost')
      end
    end

    context 'when matching against other uri' do
      context 'it is matching' do
        it 'with no uris' do
          expect(RepositoryUri.new(nil).matches?(nil)).to be
        end

        it 'with local file system paths' do
          other = URIish.new('/git/foo.git')
          expect(RepositoryUri.new('/git/foo.git').matches?(other)).to be
        end

        it 'with regular uris' do
          other = URIish.new('http://localhost/diaspora')
          expect(subject.matches?(other)).to be
        end
      end

      context 'it is not matching' do
        it 'when repo uris do not match' do
          other = URIish.new('http://localhost/other')
          expect(subject.matches?(other)).not_to be
        end
      end
    end
  end
end
