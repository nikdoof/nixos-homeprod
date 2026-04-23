
output "ns_ips" {
  description = "Public IPs of the DNS servers"
  value       = [aws_eip.ns_03.public_ip, aws_eip.ns_04.public_ip]
}

output "gts_cdn_bucket" {
  description = "S3 bucket for the GTS CDN"
  value       = aws_s3_bucket.gts_s3.id
}

output "gts_cdn_secrets" {
  description = "Environment secrets for GTS"
  sensitive   = true
  value = {
    "GTS_STORAGE_S3_ACCESS_KEY" = aws_iam_access_key.gts_iam_access_key.id
    "GTS_STORAGE_S3_BUCKET"     = aws_s3_bucket.gts_s3.id
    "GTS_STORAGE_S3_ENDPOINT"   = join(".", slice(split(".", aws_s3_bucket.gts_s3.bucket_regional_domain_name), 1, length(split(".", aws_s3_bucket.gts_s3.bucket_regional_domain_name))))
    "GTS_STORAGE_S3_SECRET_KEY" = aws_iam_access_key.gts_iam_access_key.secret
  }
}
