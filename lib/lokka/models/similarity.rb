# frozen_string_literal: true

class Similarity
  include DataMapper::Resource

  property :id, Serial
  property :entry_id, Integer
  property :similar_entry_id, Integer
  property :score, Float

  belongs_to :entry
  belongs_to :similar_entry, model: 'Entry', child_key: :similar_entry_id
end
