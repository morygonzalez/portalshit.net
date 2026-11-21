# frozen_string_literal: true

require File.expand_path('../spec_helper', __dir__)

RSpec.describe 'Entry OpenAI handlers' do
  let(:responses) { double('responses') }
  let(:client) { double('OpenAI client', responses: responses) }
  let(:message) do
    { 'type' => 'message', 'role' => 'assistant', 'content' => [
      { 'type' => 'output_text', 'text' => JSON.generate(expected) }
    ] }
  end

  before do
    allow(OpenAI::Client).to receive(:new).and_return(client)
    allow(responses).to receive(:create).and_return('output' => response_output)
  end

  shared_examples 'parses the assistant response' do
    context 'when the message is the first output item' do
      let(:response_output) { [message] }

      it 'returns the parsed JSON' do
        expect(result).to eq(expected)
      end
    end

    context 'when other output and content items precede the text' do
      let(:response_output) do
        [
          { 'type' => 'reasoning' },
          { 'type' => 'message', 'role' => 'user', 'content' => [{ 'type' => 'output_text', 'text' => '{}' }] },
          message.merge('content' => [{ 'type' => 'refusal' }] + message['content'])
        ]
      end

      it 'finds the assistant output text' do
        expect(result).to eq(expected)
      end
    end

    context 'when no assistant output text is present' do
      let(:response_output) { [{ 'type' => 'reasoning' }] }

      it 'returns nil through the existing error handling' do
        expect { expect(result).to be_nil }.to output(/OpenAI response does not contain assistant output text/).to_stdout
      end
    end
  end

  describe EntrySummarizer do
    let(:expected) { { 'summary' => '記事の要約' } }
    let(:result) { described_class.new('タイトル', '本文').summarize }

    include_examples 'parses the assistant response'
  end

  describe EntryTagGenerator do
    let(:expected) { { 'tags' => ['タグ'] } }
    let(:result) { described_class.new('タイトル', '本文', '').generate }

    include_examples 'parses the assistant response'
  end
end
