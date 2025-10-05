################################################################################
# S3 Module - Main Configuration
# Description: S3 buckets with policies
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Module    = "s3"
      ManagedBy = "terraform"
    }
  )
}

# Add your resource configurations here
# Resources: aws_s3_bucket, aws_s3_bucket_policy
