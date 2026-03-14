# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Entry syntax_highlight' do
  let(:entry) { build(:post) }

  describe '#syntax_highlight' do
    it 'highlights code with language specified on pre tag' do
      html = '<pre class="ruby"><code>puts "hello"</code></pre>'
      result = entry.syntax_highlight(html)
      expect(result).to include('highlight')
      expect(result).to include('<div class="highlight">')
    end

    it 'highlights code with language specified on code tag' do
      html = '<pre><code class="ruby">puts "hello"</code></pre>'
      result = entry.syntax_highlight(html)
      expect(result).to include('highlight')
    end

    it 'auto-detects language when no class specified' do
      html = '<pre><code>#!/bin/bash
echo "hello"</code></pre>'
      result = entry.syntax_highlight(html)
      expect(result).to include('highlight')
    end

    it 'leaves content without pre tags unchanged' do
      html = '<p>No code here</p>'
      result = entry.syntax_highlight(html)
      expect(result).to eq('<p>No code here</p>')
    end

    it 'skips highlighting on error (unknown language)' do
      html = '<pre class="nonexistent_language_xyz"><code>some code</code></pre>'
      result = entry.syntax_highlight(html)
      # Should not raise, may leave as-is or highlight depending on Rouge behavior
      expect(result).to be_a(String)
    end

    it 'handles multiple pre blocks' do
      html = '<pre class="ruby"><code>puts 1</code></pre><pre class="python"><code>print(1)</code></pre>'
      result = entry.syntax_highlight(html)
      expect(result.scan('highlight').length).to eq(2)
    end
  end
end
