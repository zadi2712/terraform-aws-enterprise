################################################################################
# ECR Module Outputs
################################################################################

output "repository_arn" {
  description = "Full ARN of the ECR repository"
  value       = aws_ecr_repository.this.arn
}

output "repository_url" {
  description = "URL of the ECR repository (for docker push/pull)"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.this.name
}

output "repository_registry_id" {
  description = "Registry ID where the repository was created"
  value       = aws_ecr_repository.this.registry_id
}

output "repository_id" {
  description = "The ID of the repository"
  value       = aws_ecr_repository.this.id
}

################################################################################
# Scanning Outputs
################################################################################

output "scan_on_push_enabled" {
  description = "Whether scan on push is enabled"
  value       = var.scan_on_push
}

output "enhanced_scanning_enabled" {
  description = "Whether enhanced scanning is enabled"
  value       = var.enable_enhanced_scanning
}

output "scan_findings_log_group" {
  description = "CloudWatch log group for scan findings"
  value       = var.enable_scan_findings_logging ? aws_cloudwatch_log_group.scan_findings[0].name : null
}

################################################################################
# Encryption Outputs
################################################################################

output "encryption_type" {
  description = "Encryption type used for the repository"
  value       = var.encryption_type
}

output "kms_key_arn" {
  description = "KMS key ARN used for encryption (if KMS encryption is enabled)"
  value       = var.encryption_type == "KMS" ? var.kms_key_arn : null
}

################################################################################
# Policy Outputs
################################################################################

output "lifecycle_policy_enabled" {
  description = "Whether lifecycle policy is enabled"
  value       = var.lifecycle_policy != null || var.max_image_count > 0
}

output "cross_account_access_enabled" {
  description = "Whether cross-account access is enabled"
  value       = var.enable_cross_account_access
}

output "lambda_pull_enabled" {
  description = "Whether Lambda pull access is enabled"
  value       = var.enable_lambda_pull
}

################################################################################
# Replication Outputs
################################################################################

output "replication_enabled" {
  description = "Whether replication is enabled"
  value       = var.enable_replication
}

output "replication_destinations" {
  description = "List of replication destinations"
  value       = var.enable_replication ? var.replication_destinations : []
}

################################################################################
# Additional Outputs
################################################################################

output "image_tag_mutability" {
  description = "Tag mutability setting for the repository"
  value       = var.image_tag_mutability
}

output "pull_through_cache_enabled" {
  description = "Whether pull through cache is enabled"
  value       = var.enable_pull_through_cache
}
