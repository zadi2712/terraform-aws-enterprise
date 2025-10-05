################################################################################
# KMS Module - Main Configuration
# Description: KMS encryption keys
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Module    = "kms"
      ManagedBy = "terraform"
    }
  )
}

# Add your resource configurations here
# Resources: aws_kms_key, aws_kms_alias
