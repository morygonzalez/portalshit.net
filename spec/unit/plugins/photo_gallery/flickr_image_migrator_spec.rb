# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require_relative '../../../../public/plugin/lokka-photo_gallery/lib/lokka/photo_gallery/flickr_image_migrator'

RSpec.describe Lokka::PhotoGallery::FlickrImageMigrator do
  FakeEntry = Struct.new(:id, :title, :raw_body) do
    attr_reader :updated_columns

    def update_columns(columns)
      @updated_columns = columns
      self.raw_body = columns[:body]
    end
  end

  let(:entry) do
    FakeEntry.new(
      10,
      'Flickr entry',
      <<~HTML
        <a href="https://www.flickr.com/photos/morygonzalez/45408683155/">
          <img src="https://farm5.staticflickr.com/4844/45408683155_5c0a8b4dc5_h.jpg">
        </a>
        <img src="https://live.staticflickr.com/4844/45408683155_5c0a8b4dc5_b.jpg">
      HTML
    )
  end

  around do |example|
    Dir.mktmpdir do |directory|
      @directory = directory
      example.run
    end
  end

  def write_image(filename, contents = 'jpeg data')
    path = File.join(@directory, filename)
    File.binwrite(path, contents)
    path
  end

  it 'matches multiple Flickr sizes to one downloaded image by photo ID' do
    path = write_image('DSC_0233_45408683155_o.jpg')
    migrator = described_class.new(entries: [entry], image_directory: @directory)

    plan = migrator.build_plan
    photo = plan[:photos].first

    expect(plan.slice(:entry_count, :source_url_count, :photo_count, :resolved_count)).to eq(
      entry_count: 1,
      source_url_count: 2,
      photo_count: 1,
      resolved_count: 1
    )
    expect(photo[:local_path]).to eq(path)
    expect(photo[:target_url]).to match(%r{\Ahttps://resources\.portalshit\.net/[0-9a-f]{32}\.jpg\z})
  end

  it 'reports missing and ambiguous local images without guessing' do
    write_image('first_45408683155_o.jpg')
    write_image('second_45408683155_o.jpg')
    missing_entry = FakeEntry.new(
      11,
      'Missing',
      '<img src="http://static.flickr.com/73/173515132_0b7472d273.jpg">'
    )
    migrator = described_class.new(entries: [entry, missing_entry], image_directory: @directory)

    plan = migrator.build_plan

    expect(plan[:ambiguous_count]).to eq(1)
    expect(plan[:missing_count]).to eq(1)
  end

  it 'uses an explicit photo ID mapping when the filename has no ID' do
    path = write_image('original-name.jpg')
    migrator = described_class.new(
      entries: [entry],
      image_directory: @directory,
      explicit_mapping: { '45408683155' => path }
    )

    expect(migrator.build_plan[:resolved_count]).to eq(1)
  end

  it 'ignores macOS archive metadata files' do
    path = write_image('DSC_0233_45408683155_o.jpg')
    FileUtils.mkdir_p(File.join(@directory, '__MACOSX'))
    File.binwrite(File.join(@directory, '__MACOSX', '._DSC_0233_45408683155_o.jpg'), 'metadata')
    File.binwrite(File.join(@directory, '._DSC_0233_45408683155_o.jpg'), 'metadata')
    migrator = described_class.new(entries: [entry], image_directory: @directory)

    photo = migrator.build_plan[:photos].first

    expect(photo[:status]).to eq('resolved')
    expect(photo[:local_path]).to eq(path)
  end

  it 'uploads once, rewrites CDN URLs, and preserves the Flickr photo-page link' do
    write_image('DSC_0233_45408683155_o.jpg')
    migrator = described_class.new(entries: [entry], image_directory: @directory)
    plan = migrator.build_plan
    uploader = instance_double(Lokka::PhotoGallery::S3Uploader)
    expect(uploader).to receive(:upload).once

    result = migrator.apply!(plan, uploader: uploader, strip_gps: false)

    expect(result).to eq(uploaded_photos: 1, removed_photos: 0, updated_entries: 1)
    expect(entry.raw_body).to include('href="https://www.flickr.com/photos/morygonzalez/45408683155/"')
    expect(entry.raw_body.scan('https://resources.portalshit.net/').count).to eq(2)
    expect(entry.raw_body).not_to include('staticflickr')
  end


  it 'removes an explicitly selected Flickr embed and its unused script' do
    removable_entry = FakeEntry.new(
      12,
      'Third-party Flickr photo',
      <<~HTML
        <p>Before</p>
        <a data-flickr-embed="true" href="https://www.flickr.com/photos/example/35230487880/" title="Storm"><img src="https://farm5.staticflickr.com/4280/35230487880_fbdd681593_b.jpg" width="1024" height="683" alt="Storm"></a><script async src="//embedr.flickr.com/assets/client-code.js" charset="utf-8"></script>
        <p>After</p>
      HTML
    )
    migrator = described_class.new(
      entries: [removable_entry],
      image_directory: @directory,
      removal_photo_ids: ['35230487880']
    )
    plan = migrator.build_plan
    uploader = instance_double(Lokka::PhotoGallery::S3Uploader)

    result = migrator.apply!(plan, uploader: uploader, strip_gps: false)

    expect(plan[:removal_count]).to eq(1)
    expect(result).to eq(uploaded_photos: 0, removed_photos: 1, updated_entries: 1)
    expect(removable_entry.raw_body).to include('<p>Before</p>', '<p>After</p>')
    expect(removable_entry.raw_body).not_to include('staticflickr', 'flickr.com', '<script')
  end

  it 'removes Flickr embed markup while preserving another migrated image and its link' do
    other_url = 'https://live.staticflickr.com/4844/45408683155_5c0a8b4dc5_b.jpg'
    removable_entry = FakeEntry.new(
      13,
      'Two Flickr photos',
      <<~HTML
        <a data-flickr-embed="true"><img src="https://farm5.staticflickr.com/4280/35230487880_fbdd681593_b.jpg"></a>
        <a data-flickr-embed="true" data-footer="true" href="https://www.flickr.com/photos/morygonzalez/45408683155/"><img src="#{other_url}"></a>
        <script async src="//embedr.flickr.com/assets/client-code.js"></script>
      HTML
    )
    write_image('DSC_0233_45408683155_o.jpg')
    migrator = described_class.new(
      entries: [removable_entry],
      image_directory: @directory,
      removal_photo_ids: ['35230487880']
    )

    plan = migrator.build_plan
    uploader = instance_double(Lokka::PhotoGallery::S3Uploader)
    expect(uploader).to receive(:upload).once
    migrator.apply!(plan, uploader: uploader, strip_gps: false)

    expect(plan[:markup_cleanup_entry_count]).to eq(1)
    expect(removable_entry.raw_body).to include(
      'href="https://www.flickr.com/photos/morygonzalez/45408683155/"',
      'https://resources.portalshit.net/'
    )
    expect(removable_entry.raw_body).not_to include(
      '35230487880', 'data-flickr-embed', 'data-footer', '<script'
    )
  end

  it 'can clean up stale Flickr embed markup after image URLs have already migrated' do
    migrated_entry = FakeEntry.new(
      14,
      'Already migrated',
      <<~HTML
        <a data-flickr-embed="true" href="https://www.flickr.com/photos/morygonzalez/45408683155/"><img src="https://resources.portalshit.net/0123456789abcdef0123456789abcdef.jpg"></a>
        <script async src="https://embedr.flickr.com/assets/client-code.js"></script>
      HTML
    )
    migrator = described_class.new(entries: [migrated_entry], image_directory: @directory)
    plan = migrator.build_plan

    result = migrator.apply!(
      plan,
      uploader: instance_double(Lokka::PhotoGallery::S3Uploader),
      strip_gps: false
    )

    expect(plan[:photo_count]).to eq(0)
    expect(plan[:markup_cleanup_entry_count]).to eq(1)
    expect(result).to eq(uploaded_photos: 0, removed_photos: 0, updated_entries: 1)
    expect(migrated_entry.raw_body).to include(
      'href="https://www.flickr.com/photos/morygonzalez/45408683155/"',
      'https://resources.portalshit.net/0123456789abcdef0123456789abcdef.jpg'
    )
    expect(migrated_entry.raw_body).not_to include('data-flickr-embed', '<script')
  end

  it 'refuses to apply a plan with unresolved photos' do
    migrator = described_class.new(entries: [entry], image_directory: @directory)
    plan = migrator.build_plan

    expect do
      migrator.apply!(plan, uploader: instance_double(Lokka::PhotoGallery::S3Uploader))
    end.to raise_error(described_class::UnresolvedImagesError)
  end
end
