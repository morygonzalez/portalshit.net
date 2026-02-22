# frozen_string_literal: true

module Dify
  class ChunkingConfig
    attr_reader :chunk_size, :delimiter

    def initialize(chunk_size:, chunk_delimiter:, default_delimiter:, env: ENV)
      @env = env
      @default_delimiter = default_delimiter
      @chunk_size = normalize_chunk_size(chunk_size)
      @delimiter = normalize_delimiter(chunk_delimiter)
    end

    def process_rule
      return nil if chunk_size.nil? && delimiter.nil?

      segmentation = {}
      if chunk_size
        segmentation[:max_tokens] = chunk_size
        segmentation[:chunk_overlap] = 150
      end

      if delimiter
        segmentation[:separators] = [delimiter]
        segmentation[:separator] = delimiter
        segmentation[:strategy] = 'separator'
      end

      { mode: 'custom', rules: { pre_processing_rules: [], segmentation: segmentation } }
    end

    private

    attr_reader :env, :default_delimiter

    def normalize_chunk_size(value)
      candidate = presence(value) ? value : env['CHUNK_SIZE']
      return nil if candidate.nil?

      n = candidate.to_i
      n.positive? ? n : nil
    end

    def normalize_delimiter(value)
      candidate = presence(value) ? value : env['CHUNK_DELIMITER']
      candidate = default_delimiter unless presence(candidate)
      candidate
    end

    def presence(value)
      case value
      when nil then false
      when String then !value.empty?
      else true
      end
    end
  end
end
