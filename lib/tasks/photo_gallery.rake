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

def reverse_geocode(gps_position)
  lat, lon = gps_position.split(',').map {|coord| dms_to_decimal(coord.strip) }
  url = "https://nominatim.openstreetmap.org/reverse?lat=#{lat}&lon=#{lon}&format=json&accept-language=ja"
  response = URI.open(url, 'User-Agent' => 'portalshit.net/1.0 (morygonzalez@gmail.com)')
  data = JSON.parse(response.read)

  # address = data['address'] || {}
  # prefecture = address['state'] || address['province']
  # city = address['city'] || address['county'] + address['town'] || address['county'] + address['village']
  # ward = address['borough'] || address['suburb']
  # neighbourhood = address['neighbourhood']
  # name = data['name']
  # %(#{prefecture}#{city}#{ward}#{neighbourhood}#{name})

  data['display_name'].split(', ')[0..-3].reverse[0..4].join
rescue StandardError => e
  warn "Reverse geocoding failed for (#{lat}, #{lon}): #{e.message}"
  nil
end

def dms_to_decimal(dms)
  match = dms.match(/(\d+) deg (\d+)' ([\d.]+)" ([NSEW])/)
  degrees = match[1].to_f
  minutes = match[2].to_f
  seconds = match[3].to_f
  direction = match[4]

  decimal = degrees + (minutes / 60.0) + (seconds / 3600.0)

  # S, Wならマイナス
  if direction == 'S' || direction == 'W'
    decimal *= -1
  end

  decimal
end

task :photo_gallery, [:folder, :do_upload, :get_location] do |task, arguments|
  folder = arguments[:folder]  # 画像が入っているフォルダを指定
  do_upload = ActiveModel::Type::Boolean.new.cast(arguments[:do_upload])
  get_location = ActiveModel::Type::Boolean.new.cast(arguments[:get_location])

  # 対象の画像拡張子リスト
  image_extensions = %w[jpg jpeg png gif]

  # ファイル一覧を取得＆フィルタ
  images = Dir.entries(folder).select do |file|
    ext = File.extname(file).downcase.delete_prefix('.')
    image_extensions.include?(ext)
  end

  # HTML生成
  image_hashes = images.map.with_index do |filename, index|
    sleep 1 if index > 0

    filepath = File.join(folder, filename)
    digest = Digest::MD5.file(filepath).to_s
    extname = File.extname(filepath)
    s3_filename = digest + extname
    upload(filepath, s3_filename) if do_upload
    url = "https://resources.portalshit.net/#{s3_filename}"
    thumb_url = "https://portalshit.net/imageproxy/115/#{url}"
    alt = filename.sub(/\.(jpe?g|png|gif)\z/, '')
    exiftool_command = <<~CMD.strip_heredoc
      exiftool -s -s -s \
        -Model -LensModel -FNumber -ShutterSpeed -ISO -FocalLengthIn35mmFormat \
        -ImageWidth -ImageHeight \
        -DateTimeOriginal -d "%Y-%m-%d %H:%M:%S" \
        -GpsPosition \
        "#{filepath}"
    CMD
    camera, lens, f_number, shutter_speed, iso, focal_length, width, height, taken_at, gps_position = `#{exiftool_command}`.chomp.split("\n")
    location = reverse_geocode(gps_position) if get_location && gps_position.present?

    {
      filename: filename,
      s3_filename: s3_filename,
      width: width,
      height: height,
      alt: alt,
      taken_at: taken_at,
      url: url,
      thumb_url: thumb_url,
      camera: camera,
      lens: lens,
      f_number: f_number,
      shutter_speed: shutter_speed,
      iso: iso,
      focal_length: focal_length,
      location: location
    }
  end

  gallery_tags = ''
  image_hashes.sort_by {|item| item[:taken_at] }.each.with_index(1) {|item, index|
    item[:thumb_url] = "https://portalshit.net/imageproxy/1280x/#{item[:url]}" if index == 1
    gallery_tags += <<~ERUBY
      <a href="#{item[:url]}" data-pswp-width="#{item[:width]}" data-pswp-height="#{item[:height]}" data-taken-at="#{item[:taken_at]}">
        <img src="#{item[:thumb_url]}" alt="#{item[:alt]}">
        <ul class="pswp-caption-content">
          <li class="title">#{item[:alt]}</li>
          <li class="meta">カメラ: #{item[:camera]}</li>
          <li class="meta">レンズ: #{item[:lens]}</li>
          <li class="meta">F値: #{item[:f_number]}</li>
          <li class="meta">シャッタースピード: #{item[:shutter_speed]}</li>
          <li class="meta">ISO感度: #{item[:iso]}</li>
          <li class="meta">焦点距離: #{item[:focal_length]}</li>
          <li class="meta">撮影日時: #{item[:taken_at]}</li>
          <li class="meta">撮影場所: #{item[:location]}</li>
        </ul>
      </a>
    ERUBY
  }

  puts <<~OUTPUT
  <div class="photo-gallery pswp-gallery">
    #{gallery_tags.strip}
  </div>
  OUTPUT
end
