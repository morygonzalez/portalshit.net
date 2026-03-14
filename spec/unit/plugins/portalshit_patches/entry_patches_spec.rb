# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Entry portalshit_patches' do
  let(:entry) { create(:post) }

  describe '#long_body_with_figure' do
    it 'wraps root-level img in figure' do
      entry.update(body: '<img src="test.jpg">')
      # Reset memoized value
      entry.instance_variable_set(:@long_body_with_figure, nil)
      result = entry.long_body_with_figure
      expect(result).to include('<figure>')
      expect(result).to include('test.jpg')
    end

    it 'converts title attribute to figcaption' do
      entry.update(body: '<img src="test.jpg" title="My Caption">')
      entry.instance_variable_set(:@long_body_with_figure, nil)
      result = entry.long_body_with_figure
      expect(result).to include('<figcaption>My Caption</figcaption>')
    end

    it 'does not add figcaption when no title' do
      entry.update(body: '<img src="test.jpg">')
      entry.instance_variable_set(:@long_body_with_figure, nil)
      result = entry.long_body_with_figure
      expect(result).not_to include('<figcaption>')
    end

    it 'replaces p parent when img is only child' do
      entry.update(body: '<p><img src="test.jpg"></p>')
      entry.instance_variable_set(:@long_body_with_figure, nil)
      result = entry.long_body_with_figure
      expect(result).to include('<figure>')
      expect(result).not_to match(%r{<p>\s*<figure>})
    end
  end

  describe '#long_description' do
    it 'strips HTML tags' do
      entry.update(body: '<p>Hello <strong>world</strong></p>')
      entry.instance_variable_set(:@long_body_with_figure, nil)
      result = entry.long_description
      expect(result).to include('Hello world')
      expect(result).not_to include('<p>')
      expect(result).not_to include('<strong>')
    end

    it 'removes figcaption content' do
      entry.update(body: '<figure><img src="x.jpg"><figcaption>Caption</figcaption></figure><p>Text</p>')
      entry.instance_variable_set(:@long_body_with_figure, nil)
      result = entry.long_description
      expect(result).not_to include('Caption')
      expect(result).to include('Text')
    end

    it 'truncates at the specified limit' do
      long_text = 'a' * 200
      entry.update(body: "<p>#{long_text}</p>")
      entry.instance_variable_set(:@long_body_with_figure, nil)
      result = entry.long_description(50)
      # limit is 0-indexed slice, so 51 chars + "..."
      expect(result.length).to be <= 55
      expect(result).to end_with('...')
    end
  end

  describe '#body_with_toc' do
    it 'replaces <!-- toc --> marker with table of contents' do
      entry.update(markup: 'redcarpet', body: "<!-- toc -->\n\n## Heading One\n\nContent\n\n## Heading Two\n\nMore content")
      entry.instance_variable_set(:@long_body_with_figure, nil)
      entry.instance_variable_set(:@toc, nil)
      result = entry.body_with_toc
      expect(result).to include('Table of Contents')
    end

    it 'returns body unchanged when no toc marker' do
      entry.update(body: '<p>No toc here</p>')
      entry.instance_variable_set(:@long_body_with_figure, nil)
      entry.instance_variable_set(:@toc, nil)
      result = entry.body_with_toc
      expect(result).not_to include('Table of Contents')
    end
  end

  describe '#images' do
    it 'extracts img src attributes' do
      entry.update(body: '<img src="a.jpg"><img src="b.png">')
      entry.instance_variable_set(:@long_body_with_figure, nil)
      entry.instance_variable_set(:@images, nil)
      expect(entry.images).to include('a.jpg', 'b.png')
    end

    it 'extracts video poster attributes' do
      entry.update(body: '<p><video poster="thumb.jpg" src="video.mp4"></video></p>')
      entry.instance_variable_set(:@long_body_with_figure, nil)
      entry.instance_variable_set(:@images, nil)
      expect(entry.images).to include('thumb.jpg')
    end
  end

  describe '#cover_image' do
    it 'returns first image when it is jpg/png/gif' do
      entry.update(body: '<img src="photo.jpg">')
      entry.instance_variable_set(:@long_body_with_figure, nil)
      entry.instance_variable_set(:@images, nil)
      expect(entry.cover_image).to eq('photo.jpg')
    end

    it 'returns default image for non-standard formats' do
      entry.update(body: '<img src="photo.webp">')
      entry.instance_variable_set(:@long_body_with_figure, nil)
      entry.instance_variable_set(:@images, nil)
      expect(entry.cover_image).to eq('https://portalshit.net/theme/portalshit/ogp_image.png')
    end

    it 'returns default image when no images' do
      entry.update(body: '<p>No images</p>')
      entry.instance_variable_set(:@long_body_with_figure, nil)
      entry.instance_variable_set(:@images, nil)
      expect(entry.cover_image).to eq('https://portalshit.net/theme/portalshit/ogp_image.png')
    end
  end
end
