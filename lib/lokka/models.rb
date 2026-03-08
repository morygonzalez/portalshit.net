# frozen_string_literal: true

%w[
  entry
  entry/page
  entry/post
  category
  comment
  field
  field_name
  markup
  option
  site
  snippet
  tag
  tagging
  theme
  user
  similarity
  entry_term_frequency
].each do |model|
  require "lokka/models/#{model}"
end
