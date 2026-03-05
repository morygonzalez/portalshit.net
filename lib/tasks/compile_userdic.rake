desc "Compile MeCab userdic from CSV"
task :compile_userdic do
  userdic_csv = File.expand_path('lib/tokenizer/userdic.csv')
  userdic_dic = File.expand_path('lib/tokenizer/userdic.dic')

  # Find system dictionary path
  dicdir = `mecab-config --dicdir 2>/dev/null`.strip
  if dicdir.empty?
    abort "mecab-config not found. Install MeCab first."
  end

  # Prefer neologd, fall back to ipadic
  system_dic = Dir.glob(File.join(dicdir, '{mecab-ipadic-neologd,ipadic}')).first
  if system_dic.nil?
    abort "No MeCab dictionary found in #{dicdir}. Install mecab-ipadic or mecab-ipadic-neologd."
  end

  # Find mecab-dict-index (not always in PATH)
  dict_index = `mecab-config --libexecdir 2>/dev/null`.strip
  dict_index_cmd = if !dict_index.empty? && File.exist?(File.join(dict_index, 'mecab-dict-index'))
                     File.join(dict_index, 'mecab-dict-index')
                   else
                     'mecab-dict-index'
                   end

  puts "Compiling userdic with system dictionary: #{system_dic}"
  system(
    dict_index_cmd,
    '-d', system_dic,
    '-u', userdic_dic,
    '-f', 'utf-8',
    '-t', 'utf-8',
    userdic_csv
  ) || abort("Failed to compile userdic")
  puts "Generated #{userdic_dic}"
end
