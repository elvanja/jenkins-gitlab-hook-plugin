require 'spec_helper'

module GitlabWebHook
  describe ParseRequest do
    let(:parameters) { JSON.parse(File.read('spec/fixtures/default_params.json')) }
    let(:body) { File.new('spec/fixtures/default_payload.json') }
    let(:request) { OpenStruct.new(body: body) }

    context 'with data from params' do
      it 'builds parameters influenced details' do
        details = subject.from(parameters, nil)
        expect(details.repository_url).to eq('http://localhost/peronospora')
      end
    end

    context 'with data from request' do
      it 'builds payload influenced details' do
        details = subject.from({}, request)
        expect(details.repository_url).to eq('git@example.com:diaspora.git')
      end
    end

    context 'with parameters' do
      context 'when empty' do
        let(:parameters) { {} }

        it 'raises exception' do
          expect { subject.from(parameters, nil) }.to raise_exception(BadRequestException)
        end
      end

      context 'with invalid details' do
        let(:parameters) { {key: "value"} }

        it 'raises exception' do
          expect { subject.from(parameters, nil) }.to raise_exception(BadRequestException)
        end
      end
    end

    context 'with body' do
      context 'when unreadable' do
        it 'raises exception' do
          expect(body).to receive(:read).and_raise()
          expect { subject.from({}, OpenStruct.new(body: body)) }.to raise_exception(BadRequestException)
        end
      end

      context 'when non rewindable' do
        it 'raises exception' do
          expect(body).to receive(:read).and_raise()
          expect { subject.from({}, OpenStruct.new(body: body)) }.to raise_exception(BadRequestException)
        end
      end

      context 'when empty' do
        it 'raises exception' do
          expect(body).to receive(:read).and_return('')
          expect { subject.from({}, OpenStruct.new(body: body)) }.to raise_exception(BadRequestException)
        end
      end

      context 'when invalid json' do
        it 'raises exception' do
          expect(body).to receive(:read).and_return('{"key": "value", 456456}')
          expect { subject.from({}, OpenStruct.new(body: body)) }.to raise_exception(BadRequestException)
        end
      end

      context 'with invalid details' do
        it 'raises exception' do
          expect(body).to receive(:read).and_return('{"key": "value"}')
          expect { subject.from({}, OpenStruct.new(body: body)) }.to raise_exception(BadRequestException)
        end
      end
    end
  end
end