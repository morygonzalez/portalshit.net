desc 'Set Cache-Control Header to S3 bucket image'
task :set_cache_control do
  credentials = Aws::Credentials.new(Option.aws_access_key_id, Option.aws_secret_access_key)
  s3 = Aws::S3::Resource.new(region: Option.s3_region, credentials: credentials)
  bucket = s3.bucket(Option.s3_bucket_name)
  target = bucket.objects.select {|obj| obj.key =~ /^theme-images/ }
  target.each do |object|
    object.copy_from(
      object,
      cache_control: 'max-age=2592000,s-maxage=31536000',
      metadata_directive: 'REPLACE'
    )
  end
end
