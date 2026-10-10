require 'spec_helper'
require_relative '../../../../public/plugin/lokka-photo_gallery/lib/lokka/photo_gallery'

describe Lokka::PhotoGallery do
  let(:images) do
    [
      { filename: 'Album 10.jpg', s3_filename: '10.jpg', url: 'https://example.test/10.jpg', thumb_url: 'https://example.test/thumb-10.jpg', taken_at: '2020-01-01' },
      { filename: 'Album 2.jpg', s3_filename: '2.jpg', url: 'https://example.test/2.jpg', thumb_url: 'https://example.test/thumb-2.jpg', taken_at: '2022-01-01' },
      { filename: 'Album 1.jpg', s3_filename: '1.jpg', url: 'https://example.test/1.jpg', thumb_url: 'https://example.test/thumb-1.jpg', taken_at: '2021-01-01' }
    ]
  end

  it 'sorts sequential filenames numerically instead of by capture time' do
    expect(described_class.sort_by_filename(images).map { |image| image[:filename] }).
      to eq(['Album 1.jpg', 'Album 2.jpg', 'Album 10.jpg'])
  end

  it 'defaults to filename order without modifying the input array' do
    original = images.dup
    expect(described_class.sort_images(images).map { |image| image[:filename] }).
      to eq(['Album 1.jpg', 'Album 2.jpg', 'Album 10.jpg'])
    expect(described_class.sort_images(images, sort_by: 'filename')).to eq(described_class.sort_by_filename(images))
    expect(images).to eq(original)
  end

  it 'sorts by capture time when requested' do
    expect(described_class.sort_images(images, sort_by: 'taken_at').map { |image| image[:s3_filename] }).
      to eq(%w[10.jpg 1.jpg 2.jpg])
  end

  it 'normalizes EXIF dates and ISO dates with timezone offsets' do
    expected = described_class.capture_time('2025:02:01 10:00:00')
    ['2025-02-01 10:00:00 +0900', '2025-02-01T10:00:00+09:00', '2025-02-01T01:00:00Z'].each do |date|
      expect(described_class.capture_time(date)).to eq(expected)
    end
    expect(described_class.capture_time('2025-02-01')).to eq(described_class.capture_time('2025:02:01 00:00:00'))
  end

  it 'orders equal timestamps and missing or invalid timestamps by numbered filename' do
    dated = [
      { filename: '10.jpg', taken_at: '2025:02:01 10:00:00' },
      { filename: '2.jpg', taken_at: '2025-02-01T01:00:00Z' },
      { filename: '3.jpg', taken_at: '2025-02-30' },
      { filename: '1.jpg', taken_at: nil },
      { filename: '4.jpg', taken_at: '' },
      { filename: '5.jpg', taken_at: 'not a date' }
    ]
    expect(described_class.sort_images(dated, sort_by: 'taken_at').map { |image| image[:filename] }).
      to eq(%w[2.jpg 10.jpg 1.jpg 3.jpg 4.jpg 5.jpg])
    ['2025-02-30', '2025:02:01 24:00:00', '2025:02:01 10:00:60', 'not a date', nil].each do |date|
      expect(described_class.capture_time(date)).to be_nil
    end
  end

  it 'rejects unsupported sort options' do
    expect { described_class.sort_images(images, sort_by: 'unknown') }.to raise_error(ArgumentError)
  end

  it 'uses the requested order when parsing images from the admin form' do
    expect(parse_gallery_images(images.to_json).map { |image| image[:s3_filename] }).to eq(%w[1.jpg 2.jpg 10.jpg])
    expect(parse_gallery_images(images.to_json, sort_by: 'taken_at').map { |image| image[:s3_filename] }).
      to eq(%w[10.jpg 1.jpg 2.jpg])
    expect(parse_gallery_images('broken JSON')).to eq([])
  end

  it 'keeps the cover first when sorting the other photos by capture time' do
    sorted = described_class.sort_images(images, sort_by: 'taken_at')
    html = described_class::Renderer.new(sorted, cover_id: '2.jpg').render
    expect(html.scan(%r{href="https://example\.test/([0-9]+)\.jpg"}).flatten).to eq(%w[2 10 1])
  end

  it 'puts the selected cover first, then keeps the remaining photos in numbered order' do
    sorted = described_class.sort_by_filename(images)
    html = described_class::Renderer.new(sorted, cover_id: '2.jpg').render

    expect(html.scan(%r{href="https://example\.test/([0-9]+)\.jpg"}).flatten).
      to eq(%w[2 1 10])
    expect(html.scan(/class="pswp-gallery__item(?: cover)?"/)).
      to eq(['class="pswp-gallery__item cover"', 'class="pswp-gallery__item"', 'class="pswp-gallery__item"'])
  end
end
