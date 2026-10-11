# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Entry, 'body byte validation' do
  describe '.body_byte_limit' do
    it 'reads the limit from the database column' do
      column = double('body column', limit: 65_535)
      allow(Entry).to receive(:columns_hash).and_return('body' => column)

      expect(Entry.body_byte_limit).to eq(65_535)
    end

    it 'uses the MEDIUMTEXT capacity when the adapter does not expose a limit' do
      column = double('body column', limit: nil)
      allow(Entry).to receive(:columns_hash).and_return('body' => column)

      expect(Entry.body_byte_limit).to eq(16_777_215)
    end
  end

  %i[page post].each do |factory|
    context "for #{factory}" do
      let(:entry) { build(factory, body: '山' * 21_845) }

      before do
        allow(entry.class).to receive(:body_byte_limit).and_return(65_535)
      end

      it 'accepts a Japanese body at the TEXT byte boundary' do
        expect(entry.raw_body.bytesize).to eq(65_535)
        expect(entry).to be_valid
      end

      it 'rejects a Japanese body one byte over the TEXT byte boundary' do
        entry.body = entry.raw_body + 'a'

        expect(entry).not_to be_valid
        expect(entry.errors[:body]).to include(
          I18n.t('entry.errors.body_too_large', limit: 65_535, bytes: 65_536)
        )
      end

      it 'validates the raw body rather than rendered markup' do
        entry.body = '# 山'
        entry.markup = 'kramdown'
        allow(entry.class).to receive(:body_byte_limit).and_return(entry.raw_body.bytesize)

        expect(entry.body.bytesize).to be > entry.raw_body.bytesize
        expect(entry).to be_valid
      end

      it 'accepts an empty or nil body as before' do
        [nil, ''].each do |body|
          entry.body = body
          expect(entry).to be_valid
        end
      end

      it 'uses the current MEDIUMTEXT limit' do
        allow(entry.class).to receive(:body_byte_limit).and_return(16_777_215)
        entry.body = 'a' * 16_777_215
        expect(entry).to be_valid

        entry.body = entry.raw_body + 'a'
        expect(entry).not_to be_valid
        expect(entry.errors[:body]).not_to be_empty
      end
    end
  end
end
