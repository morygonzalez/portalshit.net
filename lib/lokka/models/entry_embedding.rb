# frozen_string_literal: true

class EntryEmbedding < ActiveRecord::Base
  belongs_to :entry

  def embedding_vector
    embedding.is_a?(Array) ? embedding : JSON.parse(embedding)
  end
end
