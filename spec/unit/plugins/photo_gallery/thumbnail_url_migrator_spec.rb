require 'spec_helper'
require_relative '../../../../public/plugin/lokka-photo_gallery/lib/lokka/photo_gallery/thumbnail_url_migrator'

RSpec.describe Lokka::PhotoGallery::ThumbnailUrlMigrator do
  FakeEntry = Struct.new(:raw_body) do
    def update_columns(columns)
      self.raw_body = columns.fetch(:body)
    end
  end

  it 'rewrites only legacy gallery thumbnail URLs' do
    legacy_url = 'https://portalshit.net/imageproxy/115/https://resources.portalshit.net/photo.jpg'
    entry = FakeEntry.new("<img src=\"#{legacy_url}\">")
    untouched_entry = FakeEntry.new('<img src="https://example.test/photo.jpg">')

    allow(Entry).to receive(:transaction).and_yield

    updated_entries = described_class.new(entries: [entry, untouched_entry]).apply!

    expect(updated_entries).to eq(1)
    expect(entry.raw_body).to include(
      'https://portalshit.net/imageproxy/259x388/https://resources.portalshit.net/photo.jpg'
    )
    expect(untouched_entry.raw_body).to eq('<img src="https://example.test/photo.jpg">')
  end
end
