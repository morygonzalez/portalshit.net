require 'uri'
require 'json'
require 'erb'
require_relative 'photo_gallery/renderer'

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
  data = JSON.parse(response.read).with_indifferent_access

  location = data['display_name'].split(', ')[0..-3].reverse[0..4].join

  { location: location, raw: data }
rescue StandardError => e
  warn "Reverse geocoding failed for (#{lat}, #{lon}): #{e.message}"
  { location: nil, raw: { error: e.message } }
end

def dms_to_decimal(dms)
  match = dms.match(/(\d+) deg (\d+)' ([\d.]+)" ([NSEW])/)
  degrees = match[1].to_f
  minutes = match[2].to_f
  seconds = match[3].to_f
  direction = match[4]

  decimal = degrees + (minutes / 60.0) + (seconds / 3600.0)
  decimal *= -1 if %w[S W].include?(direction)

  decimal
end

namespace :photo_gallery do
  desc '画像からmetadata.jsonを生成'
  task :generate_metadata, [:folder, :do_upload] do |_, args|
    folder = args[:folder]
    do_upload = ActiveModel::Type::Boolean.new.cast(args[:do_upload])
    metadata_file = File.join(folder, 'metadata.json')

    image_extensions = %w[jpg jpeg png gif]
    images = Dir.entries(folder).select do |file|
      ext = File.extname(file).downcase.delete_prefix('.')
      image_extensions.include?(ext)
    end

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

      camera, lens, f_number_raw, shutter_speed, iso, focal_length, width, height, taken_at, gps_position = `#{exiftool_command}`.chomp.split("\n")
      f_number = "ƒ/#{f_number_raw}"

      location_result = gps_position.present? ? reverse_geocode(gps_position) : { location: nil, raw: nil }
      *licence_text, licence_url = location_result.dig(:raw, :licence)&.split("\s")
      licence_text = licence_text.join(' ')

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
        gps_position: gps_position,
        location: location_result[:location],
        licence_text: licence_text,
        licence_url: licence_url,
        reverse_geocode_raw: location_result[:raw]
      }
    end

    File.write(metadata_file, JSON.pretty_generate(image_hashes))
    puts "Generated #{metadata_file}"
  end

  desc 'metadata.jsonからHTMLを生成'
  task :generate_html, [:folder] do |_, args|
    folder = args[:folder]
    metadata_file = File.join(folder, 'metadata.json')

    unless File.exist?(metadata_file)
      abort "#{metadata_file} が存在しません。先に rake photo_gallery:generate_metadata を実行してください。"
    end

    image_hashes = JSON.parse(File.read(metadata_file), symbolize_names: true)
    renderer = PhotoGallery::Renderer.new(image_hashes)
    puts renderer.render
  end
end
