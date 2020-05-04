# frozen_string_literal: true

class Similarity < ActiveRecord::Base
  belongs_to :entry
  belongs_to :similar_entry, class_name: 'Entry'
end
