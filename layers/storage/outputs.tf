################################################################################
# S3 Bucket Outputs
################################################################################

output "application_bucket_id" {
  description = "Application bucket ID"
  value       = module.application_bucket.bucket_id
}

output "application_bucket_arn" {
  description = "Application bucket ARN"
  value       = module.application_bucket.bucket_arn
}

output "logs_bucket_id" {
  description = "Logs bucket ID"
  value       = module.logs_bucket.bucket_id
}

output "logs_bucket_arn" {
  description = "Logs bucket ARN"
  value       = module.logs_bucket.bucket_arn
}

output "logs_bucket_name" {
  description = "Logs bucket name"
  value       = module.logs_bucket.bucket_id
}

################################################################################
# EFS Outputs
################################################################################

output "efs_file_system_id" {
  description = "EFS file system ID"
  value       = var.enable_efs ? module.efs[0].file_system_id : null
}

output "efs_file_system_arn" {
  description = "EFS file system ARN"
  value       = var.enable_efs ? module.efs[0].file_system_arn : null
}

output "efs_dns_name" {
  description = "EFS DNS name for mounting"
  value       = var.enable_efs ? module.efs[0].file_system_dns_name : null
}

output "efs_mount_target_ids" {
  description = "List of EFS mount target IDs"
  value       = var.enable_efs ? module.efs[0].mount_target_ids : []
}

output "efs_mount_target_dns_names" {
  description = "List of EFS mount target DNS names"
  value       = var.enable_efs ? module.efs[0].mount_target_dns_names : []
}

output "efs_access_point_ids" {
  description = "Map of EFS access point IDs"
  value       = var.enable_efs ? module.efs[0].access_point_ids : {}
}

output "efs_access_point_arns" {
  description = "Map of EFS access point ARNs"
  value       = var.enable_efs ? module.efs[0].access_point_arns : {}
}

output "efs_security_group_id" {
  description = "EFS security group ID"
  value       = var.enable_efs ? module.efs_security_group[0].security_group_id : null
}

output "efs_mount_command" {
  description = "Command to mount EFS file system"
  value       = var.enable_efs ? module.efs[0].mount_command_efs_utils : null
}

output "efs_info" {
  description = "Complete EFS file system information"
  value       = var.enable_efs ? module.efs[0].efs_info : null
}
