variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "logs_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 90
}

################################################################################
# S3 Configuration
################################################################################

variable "s3_force_destroy" {
  description = "Allow bucket deletion with objects (non-prod only)"
  type        = bool
  default     = false
}

variable "s3_enable_kms_encryption" {
  description = "Enable KMS encryption for S3 buckets"
  type        = bool
  default     = true
}

variable "s3_app_versioning_enabled" {
  description = "Enable versioning for application bucket"
  type        = bool
  default     = true
}

variable "s3_app_lifecycle_rules" {
  description = "Lifecycle rules for application bucket"
  type        = list(any)
  default     = []
}

variable "s3_app_intelligent_tiering" {
  description = "Intelligent Tiering configurations for application bucket"
  type        = any
  default     = {}
}

variable "s3_app_replication_enabled" {
  description = "Enable replication for application bucket"
  type        = bool
  default     = false
}

variable "s3_app_replication_rules" {
  description = "Replication rules for application bucket"
  type        = any
  default     = {}
}

variable "s3_logs_lifecycle_enabled" {
  description = "Enable lifecycle transitions for logs bucket"
  type        = bool
  default     = true
}

variable "s3_logs_intelligent_tiering_enabled" {
  description = "Enable intelligent tiering for logs bucket"
  type        = bool
  default     = false
}

variable "s3_enable_access_logging" {
  description = "Enable S3 access logging"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

################################################################################
# EFS Configuration
################################################################################

variable "enable_efs" {
  description = "Enable EFS file system"
  type        = bool
  default     = false
}

variable "efs_performance_mode" {
  description = "EFS performance mode (generalPurpose or maxIO)"
  type        = string
  default     = "generalPurpose"
}

variable "efs_throughput_mode" {
  description = "EFS throughput mode (bursting, provisioned, or elastic)"
  type        = string
  default     = "bursting"
}

variable "efs_provisioned_throughput" {
  description = "Provisioned throughput in MiB/s (only for provisioned mode)"
  type        = number
  default     = null
}

variable "efs_availability_zone_name" {
  description = "AWS Availability Zone for One Zone storage (null for Regional)"
  type        = string
  default     = null
}

variable "efs_encrypted" {
  description = "Enable EFS encryption at rest"
  type        = bool
  default     = true
}

variable "efs_transition_to_ia" {
  description = "Transition to Infrequent Access storage class"
  type        = string
  default     = null
}

variable "efs_transition_to_primary_storage_class" {
  description = "Transition back to primary storage class on first access"
  type        = string
  default     = null
}

variable "efs_enable_backup_policy" {
  description = "Enable automatic backups via AWS Backup"
  type        = bool
  default     = true
}

variable "efs_create_mount_targets" {
  description = "Create mount targets in private subnets"
  type        = bool
  default     = true
}

variable "efs_access_points" {
  description = "Map of EFS access points to create"
  type = map(object({
    posix_user = optional(object({
      gid            = number
      uid            = number
      secondary_gids = optional(list(number))
    }))
    root_directory = optional(object({
      path = optional(string, "/")
      creation_info = optional(object({
        owner_gid   = number
        owner_uid   = number
        permissions = string
      }))
    }))
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "efs_file_system_policy" {
  description = "EFS file system policy JSON"
  type        = string
  default     = null
}

variable "efs_enable_replication" {
  description = "Enable EFS replication to another region"
  type        = bool
  default     = false
}

variable "efs_replication_destination_region" {
  description = "Destination region for EFS replication"
  type        = string
  default     = null
}

variable "efs_replication_destination_availability_zone" {
  description = "Destination availability zone for One Zone replication"
  type        = string
  default     = null
}

variable "efs_replication_destination_kms_key_id" {
  description = "KMS key ID for destination file system encryption"
  type        = string
  default     = null
}
