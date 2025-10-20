################################################################################
# KMS Module - Outputs
# Version: 2.0
################################################################################

################################################################################
# Key Outputs
################################################################################

output "key_id" {
  description = "The globally unique identifier for the key"
  value       = aws_kms_key.this.key_id
}

output "key_arn" {
  description = "The Amazon Resource Name (ARN) of the key"
  value       = aws_kms_key.this.arn
}

output "key_alias_name" {
  description = "The display name of the key alias"
  value       = var.create_alias ? aws_kms_alias.this[0].name : null
}

output "key_alias_arn" {
  description = "The Amazon Resource Name (ARN) of the key alias"
  value       = var.create_alias ? aws_kms_alias.this[0].arn : null
}

################################################################################
# Key Policy Outputs
################################################################################

output "key_policy" {
  description = "The IAM resource policy for the key"
  value       = aws_kms_key.this.policy
  sensitive   = true
}

################################################################################
# Key Rotation Outputs
################################################################################

output "key_rotation_enabled" {
  description = "Whether key rotation is enabled"
  value       = aws_kms_key.this.enable_key_rotation
}

output "rotation_period_in_days" {
  description = "Rotation period in days"
  value       = aws_kms_key.this.rotation_period_in_days
}

################################################################################
# Multi-Region Outputs
################################################################################

output "multi_region" {
  description = "Whether this is a multi-region key"
  value       = aws_kms_key.this.multi_region
}

################################################################################
# Grant Outputs
################################################################################

output "grants" {
  description = "Map of grant IDs"
  value = {
    for k, v in aws_kms_grant.this : k => {
      grant_id    = v.grant_id
      grant_token = v.grant_token
    }
  }
  sensitive = true
}

output "grant_ids" {
  description = "List of grant IDs"
  value       = [for v in aws_kms_grant.this : v.grant_id]
}

################################################################################
# Metadata Outputs
################################################################################

output "key_spec" {
  description = "The type of key material in the KMS key"
  value       = aws_kms_key.this.customer_master_key_spec
}

output "key_usage" {
  description = "The cryptographic operations for which the key is designed"
  value       = aws_kms_key.this.key_usage
}

output "deletion_window_in_days" {
  description = "Duration in days after which the key is deleted"
  value       = aws_kms_key.this.deletion_window_in_days
}

################################################################################
# Complete Key Information
################################################################################

output "key_info" {
  description = "Complete KMS key information"
  value = {
    id                       = aws_kms_key.this.key_id
    arn                      = aws_kms_key.this.arn
    alias_name               = var.create_alias ? aws_kms_alias.this[0].name : null
    alias_arn                = var.create_alias ? aws_kms_alias.this[0].arn : null
    key_usage                = aws_kms_key.this.key_usage
    customer_master_key_spec = aws_kms_key.this.customer_master_key_spec
    enable_key_rotation      = aws_kms_key.this.enable_key_rotation
    rotation_period_in_days  = aws_kms_key.this.rotation_period_in_days
    multi_region             = aws_kms_key.this.multi_region
    deletion_window_in_days  = aws_kms_key.this.deletion_window_in_days
  }
}
