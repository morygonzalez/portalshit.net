require 'fastimage'
require 'uri'

def credentials
  @credentials ||= Aws::Credentials.new(
    Option.aws_access_key_id,
    Option.aws_secret_access_key
  )
end

def s3
  @s3 ||= Aws::S3::Resource.new(region: Option.s3_region, credentials: credentials)
end

def bucket
  @bucket ||= s3.bucket(Option.s3_bucket_name)
end

def upload(filepath, filename)
  content_type = Marcel::MimeType.for(File.open(filepath))
  bucket.object(filename).upload_file(
    filepath,
    content_type: content_type,
    cache_control: 'max-age=2592000,s-maxage=31536000'
  )
end

task :photo_gallery, :folder do |task, arguments|
  folder = arguments[:folder]  # 画像が入っているフォルダを指定

  # 対象の画像拡張子リスト
  image_extensions = %w[jpg jpeg png gif]

  # ファイル一覧を取得＆フィルタ
  images = Dir.entries(folder).select do |file|
    ext = File.extname(file).downcase.delete_prefix('.')
    image_extensions.include?(ext)
  end

  # HTML生成
  image_hashes = images.map do |filename|
    filepath = File.join(folder, filename)
    digest = Digest::MD5.file(filepath).to_s
    extname = File.extname(filepath)
    s3_filename = digest + extname
    upload(filepath, s3_filename)
    url = "https://resources.portalshit.net/#{s3_filename}"
    thumb_url = "https://portalshit.net/imageproxy/115/#{url}"
    alt = filename.sub(/\.(jpe?g|png|gif)\z/, '')
    taken_at = `exiftool -s -s -s -DateTimeOriginal -d "%Y-%m-%d %H:%M:%S" "#{filepath}"`.chomp
    width, height = FastImage.size(filepath)

    {
      filename: filename,
      s3_filename: s3_filename,
      width: width,
      height: height,
      alt: alt,
      taken_at: taken_at,
      url: url,
      thumb_url: thumb_url
    }
  end

  image_hashes.sort_by {|item| item[:taken_at] }.each.with_index(1) {|item, index|
    item[:thumb_url] = "https://portalshit.net/imageproxy/1280x/#{item[:url]}" if index == 1
    puts <<~ERUBY.strip_heredoc
      <a href="#{item[:url]}" data-pswp-width="#{item[:width]}" data-pswp-height="#{item[:height]}" data-taken-at="#{item[:taken_at]}">
        <img src="#{item[:thumb_url]}" alt="#{item[:taken_at]} #{item[:alt]}">
      </a>
    ERUBY
  }
end
