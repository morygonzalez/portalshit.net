require 'tantiny'
require_relative '../tokenizer'

desc "Create full text search index"
task :create_search_index, :force do |task, arguments|
  entries = Entry.includes(:category, :tags).published
  index = Lokka::Helpers.search_index
  index_path = index.instance_variable_get("@path")
  index_last_modified = File.mtime(index_path)
  entry_last_updated_at = entries.maximum(:updated_at)

  force_executeion = arguments[:force] == 'true'
  puts force_executeion

  if !force_executeion && index_last_modified > entry_last_updated_at
    puts 'Search index is up-to-date'
    next
  end

  Rake::Task[:create_new_index].invoke
  Rake::Task[:delete_old_index].invoke
end

task :create_new_index do
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

task :delete_old_index do
  index = Lokka::Helpers.search_index
  index_path = index.instance_variable_get("@path")
  index_keys = Dir.glob(File.join(index_path, '*.idx')).each_with_object({}) do |item, files|
    ctime = File.ctime(item)
    key = File.basename(item, '.idx')
    files[key] = ctime
  end
  latest_key = index_keys.sort_by {|k, v| v }.reverse.first[0]
  puts "The latest key is #{latest_key}"
  index_keys.delete(latest_key)
  if index_keys.blank?
    puts "No older index"
    next
  end
  files_to_delete = index_keys.each_with_object([]) do |(key, _), files|
    puts key
    files << Dir.glob(File.join(index_path, "#{key}.*"))
  end
  FileUtils.rm(files_to_delete)
  puts "#{files_to_delete.length} files are deleted"
end
