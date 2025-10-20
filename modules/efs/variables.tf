################################################################################
# EFS Module - Variables
# Version: 2.0
################################################################################

################################################################################
# Required Variables
################################################################################

variable "name" {
  description = "Name of the EFS file system"
  type        = string
}

################################################################################
# File System Configuration
################################################################################

variable "creation_token" {
  description = "Unique name used as reference when creating the file system"
  type        = string
  default     = null
}

variable "performance_mode" {
  description = "File system performance mode (generalPurpose or maxIO)"
  type        = string
  default     = "generalPurpose"
  
  validation {
    condition     = contains(["generalPurpose", "maxIO"], var.performance_mode)
    error_message = "performance_mode must be generalPurpose or maxIO"
  }
}

variable "throughput_mode" {
  description = "Throughput mode (bursting, provisioned, or elastic)"
  type        = string
  default     = "bursting"
  
  validation {
    condition     = contains(["bursting", "provisioned", "elastic"], var.throughput_mode)
    error_message = "throughput_mode must be bursting, provisioned, or elastic"
  }
}

variable "provisioned_throughput_in_mibps" {
  description = "Provisioned throughput in MiB/s (required if throughput_mode is provisioned)"
  type        = number
  default     = null
}

variable "availability_zone_name" {
  description = "AWS Availability Zone for One Zone storage class"
  type        = string
  default     = null
}

################################################################################
# Encryption Configuration
################################################################################

variable "encrypted" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "ARN of KMS key for encryption"
  type        = string
  default     = null
}

################################################################################
# Lifecycle Management
################################################################################

variable "transition_to_ia" {
  description = "Transition to Infrequent Access storage class (AFTER_7_DAYS, AFTER_14_DAYS, AFTER_30_DAYS, AFTER_60_DAYS, AFTER_90_DAYS, AFTER_1_DAY, AFTER_180_DAYS, AFTER_270_DAYS, AFTER_365_DAYS)"
  type        = string
  default     = null
  
  validation {
    condition = var.transition_to_ia == null || contains([
      "AFTER_1_DAY",
      "AFTER_7_DAYS",
      "AFTER_14_DAYS",
      "AFTER_30_DAYS",
      "AFTER_60_DAYS",
      "AFTER_90_DAYS",
      "AFTER_180_DAYS",
      "AFTER_270_DAYS",
      "AFTER_365_DAYS"
    ], var.transition_to_ia)
    error_message = "Invalid transition_to_ia value"
  }
}

variable "transition_to_primary_storage_class" {
  description = "Transition back to primary storage class on first access (AFTER_1_ACCESS)"
  type        = string
  default     = null
  
  validation {
    condition     = var.transition_to_primary_storage_class == null || var.transition_to_primary_storage_class == "AFTER_1_ACCESS"
    error_message = "transition_to_primary_storage_class must be AFTER_1_ACCESS or null"
  }
}

################################################################################
# Backup Configuration
################################################################################

variable "enable_backup_policy" {
  description = "Enable automatic backups via AWS Backup"
  type        = bool
  default     = true
}

################################################################################
# Network Configuration
################################################################################

variable "create_mount_targets" {
  description = "Whether to create mount targets"
  type        = bool
  default     = true
}

variable "subnet_ids" {
  description = "List of subnet IDs for mount targets (one per AZ)"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "List of security group IDs for mount targets"
  type        = list(string)
  default     = []
}

################################################################################
# Access Points Configuration
################################################################################

variable "access_points" {
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

################################################################################
# File System Policy
################################################################################

variable "file_system_policy" {
  description = "EFS file system policy JSON"
  type        = string
  default     = null
}

################################################################################
# Replication Configuration
################################################################################

variable "enable_replication" {
  description = "Enable EFS replication to another region"
  type        = bool
  default     = false
}

variable "replication_destination_region" {
  description = "Destination region for EFS replication"
  type        = string
  default     = null
}

variable "replication_destination_availability_zone" {
  description = "Destination availability zone for One Zone EFS replication"
  type        = string
  default     = null
}

variable "replication_destination_kms_key_id" {
  description = "KMS key ID for destination file system encryption"
  type        = string
  default     = null
}

variable "enable_replication_overwrite_protection" {
  description = "Enable replication overwrite protection"
  type        = bool
  default     = false
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
