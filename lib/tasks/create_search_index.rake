require 'tantiny'
require_relative '../tokenizer'

desc "Create full text search index"
task :create_search_index do
  entries = Entry.includes(:category, :tags).published

  index = Lokka::Helpers.search_index

  index.transaction do
    entries.each do |entry|
      tags_splitted = entry.tag_list.join(' ')
      title_tokenized = Tokenizer.run(entry.title).join(' ')
      body_tokenized = Tokenizer.run(entry.body).join(' ')
      category_tokenized = Tokenizer.run(entry.category.title).join(' ') if entry.category

      index << {
        id: entry.id,
        title: entry.title,
        title_tokenized: title_tokenized,
        category: entry.category,
        category_tokenized: category_tokenized,
        tags: tags_splitted,
        body: body_tokenized,
        date: entry.created_at
      }
    end
  end

  index.reload
end
