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

  it 'puts the selected cover first, then keeps the remaining photos in numbered order' do
    sorted = described_class.sort_by_filename(images)
    html = described_class::Renderer.new(sorted, cover_id: '2.jpg').render

    expect(html.scan(%r{href="https://example\.test/([0-9]+)\.jpg"}).flatten).
      to eq(%w[2 1 10])
    expect(html.scan(/class="pswp-gallery__item(?: cover)?"/)).
      to eq(['class="pswp-gallery__item cover"', 'class="pswp-gallery__item"', 'class="pswp-gallery__item"'])
  end
end
