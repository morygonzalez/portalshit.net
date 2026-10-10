require_relative 'spec_helper'

describe '/admin/photo_gallery/render' do
  include_context 'admin login'

  let(:images) do
    [
      { filename: 'Album 10.jpg', s3_filename: '10.jpg', url: 'https://example.test/10.jpg', taken_at: '2020:01:01 10:00:00' },
      { filename: 'Album 2.jpg', s3_filename: '2.jpg', url: 'https://example.test/2.jpg', taken_at: '2022-01-01' },
      { filename: 'Album 1.jpg', s3_filename: '1.jpg', url: 'https://example.test/1.jpg', taken_at: '2021-01-01' }
    ]
  end

  it 'defaults to numbered filename order' do
    post '/admin/photo_gallery/render', images: images.to_json
    expect(last_response).to be_successful
    expect(JSON.parse(last_response.body)['body'].scan(%r{href="https://example\.test/([0-9]+)\.jpg"}).flatten).
      to eq(%w[1 2 10])
  end

  it 'accepts capture time order while preserving the selected cover' do
    post '/admin/photo_gallery/render', images: images.to_json, sort_by: 'taken_at', cover_id: '2.jpg'
    expect(last_response).to be_successful
    expect(JSON.parse(last_response.body)['body'].scan(%r{href="https://example\.test/([0-9]+)\.jpg"}).flatten).
      to eq(%w[2 10 1])
  end

  it 'returns an actionable error for an unsupported order' do
    post '/admin/photo_gallery/render', images: images.to_json, sort_by: 'unknown'
    expect(last_response.status).to eq(400)
    expect(JSON.parse(last_response.body)['message']).to include('filename', 'taken_at')
  end
end
