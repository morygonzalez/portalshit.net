require 'tantiny'

task :create_search_index do
  path = File.join(Lokka.root, 'tmp', 'index')

  index = Tantiny::Index.new path do
    id :id
    string :category
    string :title
    string :tags
    text :body
    date :date
  end

  entries = Entry.includes(:category, :tags).published

  index.transaction do
    entries.each do |entry|
      index << {
        id: entry.id,
        category: entry.category&.title,
        title: entry.title,
        tags: entry.tag_list.join(' '),
        body: entry.body,
        date: entry.created_at
      }
    end
  end

  index.reload
end
