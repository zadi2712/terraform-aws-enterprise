################################################################################
# S3 Module - Outputs
# Version: 2.0
################################################################################

################################################################################
# Bucket Outputs
################################################################################

output "bucket_id" {
  description = "Bucket name (ID)"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "Bucket ARN"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "Bucket domain name"
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Bucket region-specific domain name"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "bucket_region" {
  description = "Bucket region"
  value       = aws_s3_bucket.this.region
}

output "bucket_hosted_zone_id" {
  description = "Route 53 Hosted Zone ID"
  value       = aws_s3_bucket.this.hosted_zone_id
}

################################################################################
# Website Outputs
################################################################################

output "website_endpoint" {
  description = "Website endpoint (if enabled)"
  value       = var.website_enabled ? aws_s3_bucket_website_configuration.this[0].website_endpoint : null
}

output "website_domain" {
  description = "Website domain (if enabled)"
  value       = var.website_enabled ? aws_s3_bucket_website_configuration.this[0].website_domain : null
}

################################################################################
# Replication Outputs
################################################################################

output "replication_role_arn" {
  description = "ARN of replication IAM role"
  value       = var.create_replication_role && var.replication_enabled ? aws_iam_role.replication[0].arn : var.replication_role_arn
}

################################################################################
# Summary Output
################################################################################

output "s3_info" {
  description = "Complete S3 bucket information"
  value = {
    bucket_name              = aws_s3_bucket.this.id
    bucket_arn               = aws_s3_bucket.this.arn
    region                   = aws_s3_bucket.this.region
    versioning_enabled       = var.versioning_enabled
    encryption_enabled       = true
    kms_encrypted            = var.kms_key_id != null
    public_access_blocked    = var.block_public_access
    replication_enabled      = var.replication_enabled
    website_enabled          = var.website_enabled
    lifecycle_rules_count    = length(var.lifecycle_rules)
    intelligent_tiering_count = length(var.intelligent_tiering_configurations)
  }
}
