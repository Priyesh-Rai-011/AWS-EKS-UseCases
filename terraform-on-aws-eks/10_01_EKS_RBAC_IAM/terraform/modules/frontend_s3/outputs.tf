output "bucket_name"   { value = aws_s3_bucket.frontend.bucket }
output "website_url"   { value = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}" }
