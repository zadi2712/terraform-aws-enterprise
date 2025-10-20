################################################################################
# KMS Outputs - Main Key
################################################################################

output "kms_key_id" {
  description = "Main KMS key ID"
  value       = module.kms_main.key_id
}

output "kms_key_arn" {
  description = "Main KMS key ARN"
  value       = module.kms_main.key_arn
}

output "kms_key_alias_name" {
  description = "Main KMS key alias name"
  value       = module.kms_main.key_alias_name
}

output "kms_key_alias_arn" {
  description = "Main KMS key alias ARN"
  value       = module.kms_main.key_alias_arn
}

output "kms_key_rotation_enabled" {
  description = "Whether key rotation is enabled"
  value       = module.kms_main.key_rotation_enabled
}

################################################################################
# KMS Outputs - Service-Specific Keys
################################################################################

output "kms_rds_key_id" {
  description = "RDS KMS key ID"
  value       = var.create_rds_key ? module.kms_rds[0].key_id : null
}

output "kms_rds_key_arn" {
  description = "RDS KMS key ARN"
  value       = var.create_rds_key ? module.kms_rds[0].key_arn : null
}

output "kms_s3_key_id" {
  description = "S3 KMS key ID"
  value       = var.create_s3_key ? module.kms_s3[0].key_id : null
}

output "kms_s3_key_arn" {
  description = "S3 KMS key ARN"
  value       = var.create_s3_key ? module.kms_s3[0].key_arn : null
}

output "kms_ebs_key_id" {
  description = "EBS KMS key ID"
  value       = var.create_ebs_key ? module.kms_ebs[0].key_id : null
}

output "kms_ebs_key_arn" {
  description = "EBS KMS key ARN"
  value       = var.create_ebs_key ? module.kms_ebs[0].key_arn : null
}

################################################################################
# Complete KMS Information
################################################################################

output "kms_keys_info" {
  description = "Complete information about all KMS keys"
  value = {
    main = module.kms_main.key_info
    rds  = var.create_rds_key ? module.kms_rds[0].key_info : null
    s3   = var.create_s3_key ? module.kms_s3[0].key_info : null
    ebs  = var.create_ebs_key ? module.kms_ebs[0].key_info : null
  }
}
