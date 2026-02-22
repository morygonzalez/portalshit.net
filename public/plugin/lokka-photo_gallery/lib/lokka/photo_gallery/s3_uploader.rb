module Lokka
  module PhotoGallery
    class S3Uploader
      def initialize
        credentials = Aws::Credentials.new(
          Option.aws_access_key_id,
          Option.aws_secret_access_key
        )
        s3 = Aws::S3::Resource.new(region: Option.s3_region, credentials: credentials)
        @bucket = s3.bucket(Option.s3_bucket_name)
      end

      def upload(filepath, s3_filename)
        content_type = File.open(filepath, 'rb') { |f| Marcel::MimeType.for(f) }
        object = @bucket.object(s3_filename)

        if object.exists?
          puts "[skip] s3://#{@bucket.name}/#{s3_filename} は既に存在します"
          return { skipped: true, key: s3_filename }
        end

        object.upload_file(
          filepath,
          content_type: content_type,
          cache_control: 'max-age=2592000,s-maxage=31536000'
        )

        puts "[upload] s3://#{@bucket.name}/#{s3_filename}"
        { uploaded: true, key: s3_filename }
      end
    end
  end
end
