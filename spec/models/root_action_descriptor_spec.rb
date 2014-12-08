require 'spec_helper'

describe GitlabWebHookRootActionDescriptor do
    context 'whether automatic project creation is enabled' do
      it 'defines it' do
        expect(subject).to respond_to(:automatic_project_creation?)
      end

      it 'has default' do
        expect(subject.automatic_project_creation?).to be(false)
      end
    end

    context 'with master branch identificator' do
      it 'defines it' do
        expect(subject).to respond_to(:master_branch)
      end

      it 'has default' do
        expect(subject.master_branch).to eq('master')
      end
    end

    context 'whether to use master project name' do
      it 'defines it' do
        expect(subject).to respond_to(:use_master_project_name?)
      end

      it 'has default' do
        expect(subject.use_master_project_name?).to eq(false)
      end
    end

    context 'with automatically created project description' do
      it 'defines it' do
        expect(subject).to respond_to(:description)
      end

      it 'has default' do
        expect(subject.description).to eq('Automatically created by Gitlab Web Hook plugin')
      end
    end

    context 'with any branch search pattern' do
      it 'defines it' do
        expect(subject).to respond_to(:any_branch_pattern)
      end

      it 'has default' do
        expect(subject.any_branch_pattern).to eq('**')
      end
    end

    context '#template_fallback' do
      it 'is defined' do
        expect(subject).to respond_to(:template_fallback)
      end

      it 'evaluates to false by default' do
        expect(subject.template_fallback).to be nil
      end
    end

    context '#templated_groups' do
      it 'is defined' do
        expect(subject).to respond_to(:templated_groups)
      end

      it 'has empty default' do
        expect(subject.templated_groups).to eq({})
      end
    end

    context '#templated_jobs' do
      it 'is defined' do
        expect(subject).to respond_to(:templated_jobs)
      end

      it 'has empty default' do
        expect(subject.templated_jobs).to eq({})
      end
    end

    context 'disk descriptor' do

      let(:xml_file) { double(exists: true, canonicalPath: 'spec/fixtures/descriptor.xml' ) }
      let(:config_file) { double('configFile', file: xml_file) }
      let(:subject) { GitlabWebHookRootActionDescriptor.new }

      context 'read' do

        before(:each) do
          expect(subject).to receive(:configFile).twice { config_file }
          subject.load
        end

        it '#automatic_project_creation?' do
          expect(subject.automatic_project_creation?).to be true
        end

        it '#master_branch' do
          expect(subject.master_branch).to eq 'primary'
        end

        it '#use_master_project_name?' do
          expect(subject.use_master_project_name?).to be true
        end

        it '#description' do
          expect(subject.description).to eq 'Alternate description'
        end

        it '#any_branch_pattern' do
          expect(subject.any_branch_pattern).to eq 'origin/*'
        end

        it '#template_fallback' do
          expect(subject.template_fallback).to eq 'default_project'
        end

        it '#templated_groups' do
          expect(subject.templated_groups).to eq( { 'android' => 'gradle_project' } )
        end

        it '#templated_jobs' do
          expect(subject.templated_jobs).to eq( { 'webapp-' => 'maven_project' , 'java-lib-' => 'artifactory_project' } )
        end

      end

      context 'write' do

        let (:content) { File.read('spec/fixtures/descriptor.xml') }
        let (:outfile) { StringIO.new }

        it 'recovers disk content' do
          expect(subject).to receive(:configFile).and_return( config_file ).exactly(4).times
          subject.load
          expect(BulkChange).to receive(:contains) { false }
          expect(File).to receive(:open) { outfile }
          expect(SaveableListener).to receive(:fireOnChange)
          subject.save
          expect(outfile.string).to eq content
        end

      end

    end

end
