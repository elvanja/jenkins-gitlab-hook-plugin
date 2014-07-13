require 'spec_helper'

module GitlabWebHook
  describe ParametersRequestDetails do
    let (:parameters) { JSON.parse(File.read('spec/fixtures/default_params.json')) }
    let (:subject) { ParametersRequestDetails.new(parameters) }

    context 'when initializing' do
      it 'requires parameters' do
        expect { ParametersRequestDetails.new(nil) }.to raise_exception(ArgumentError)
      end
    end

    context 'with repository url' do
      it 'extracts from parameters' do
        expect(subject.repository_url).to eq('http://localhost/peronospora')
      end

      it 'returns empty when no repository details found' do
        parameters.delete('repo_url')
        expect(subject.repository_url).to eq('')
      end
    end

    context 'with repository name' do
      it 'extracts from parameters' do
        expect(subject.repository_name).to eq('Peronospora')
      end

      it 'returns empty when no repository details found' do
        parameters.delete('repo_name')
        expect(subject.repository_name).to eq('')
      end
    end

    context 'with repository homepage' do
      it 'extracts from parameters' do
        expect(subject.repository_homepage).to eq('http://localhost/peronospora')
      end

      it 'returns empty when no repository details found' do
        parameters.delete('repo_homepage')
        expect(subject.repository_homepage).to eq('')
      end
    end

    context 'with branch' do
      it 'extracts full branch name from payeload' do
        expect(subject.full_branch_reference).to eq('refs/heads/master')
      end

      it 'returns empty full branch name when no branch reference data found' do
        parameters.delete('ref')
        expect(subject.full_branch_reference).to eq('')
      end
    end

    context 'with delete branch commit' do
      it 'defaults to false' do
        expect(subject.delete_branch_commit?).to be_falsey
      end

      it 'detects delete branch commit' do
        parameters['delete_branch_commit'] = true
        expect(subject.delete_branch_commit?).to be_truthy
      end
    end
  end
end
