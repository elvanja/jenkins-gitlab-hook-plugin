require 'spec_helper'

module GitlabWebHook
  describe ScmData do
    let(:details) { double(RequestDetails, repository_name: 'discourse', branch: 'features_meta', safe_branch: 'features_meta') }
    let(:remote_config) { double(UserRemoteConfig, getUrl: 'http://localhost/diaspora/diaspora', getName: 'Diaspora', getCredentialsId: 'id', getRefspec: ['+refs/heads/*:refs/remotes/origin/*']) }
    let(:source_scm) { double(GitSCM, getScmName: 'git', getUserRemoteConfigs: [remote_config, double(UserRemoteConfig)]).as_null_object }
    let(:subject) { described_class.new(source_scm, details) }

    context 'when building' do
      it 'it uses source scm first configuration' do
        expect(subject.url).to eq('http://localhost/diaspora/diaspora')
      end

      it 'takes url from source scm configuration' do
        expect(subject.url).to eq('http://localhost/diaspora/diaspora')
      end

      it 'takes name from source scm configuration' do
        expect(subject.name).to eq('Diaspora')
      end

      it 'takes credentials from source scm configuration' do
        expect(subject.credentials).to eq('id')
      end

      it 'takes refspec from source scm configuration' do
        expect(subject.refspec).to eq(['+refs/heads/*:refs/remotes/origin/*'])
      end

      context 'when determining branch' do
        let(:branchspec) { double(BranchSpec) }
        let(:java_branchspec) { double(BranchSpec) }
        context 'without source scm name' do
          before(:each) do
            expect(branchspec).to receive(:java_object).and_return(java_branchspec)
            expect(BranchSpec).to receive(:new).with('origin/features_meta').and_return(branchspec)
          end
          it 'uses prefixed details branch' do
            expect(remote_config).to receive(:getName).and_return(nil)
            expect(subject.branchlist).to eq([java_branchspec])
          end
        end

        context 'with source scm name present' do
          before(:each) do
            expect(branchspec).to receive(:java_object).and_return(java_branchspec)
            expect(BranchSpec).to receive(:new).with('Diaspora/features_meta').and_return(branchspec)
          end
          it 'prefixes details branch' do
            expect(subject.branchlist).to eq([java_branchspec])
          end
        end
      end

      context 'when validating' do
        context 'with url present' do
          it 'does not raise exception' do
            expect { described_class.new(source_scm, details) }.not_to raise_exception
          end
        end

        context 'without url' do
          it 'raises appropriate exception' do
            expect(remote_config).to receive(:getUrl).and_return(nil)
            expect { described_class.new(source_scm, details) }.to raise_exception(ConfigurationException)
          end
        end
      end
    end
  end
end
