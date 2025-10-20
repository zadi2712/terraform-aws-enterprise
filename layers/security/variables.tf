################################################################################
# General Configuration
################################################################################

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

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

################################################################################
# KMS Configuration - Main Key
################################################################################

variable "kms_main_description" {
  description = "Description of the main KMS key"
  type        = string
  default     = "Main encryption key for general purpose encryption"
}

variable "kms_deletion_window_in_days" {
  description = "Duration in days after which the key is deleted after destruction"
  type        = number
  default     = 30
}

variable "kms_enable_key_rotation" {
  description = "Enable automatic key rotation"
  type        = bool
  default     = true
}

variable "kms_rotation_period_in_days" {
  description = "Custom period of time in days between each rotation"
  type        = number
  default     = 365
}

variable "kms_key_administrators" {
  description = "List of IAM ARNs that can administer KMS keys"
  type        = list(string)
  default     = []
}

variable "kms_key_users" {
  description = "List of IAM ARNs that can use KMS keys"
  type        = list(string)
  default     = []
}

variable "kms_service_principals" {
  description = "List of AWS service principals that can use KMS keys"
  type        = list(string)
  default     = []
}

variable "kms_via_service_conditions" {
  description = "List of AWS services for kms:ViaService condition"
  type        = list(string)
  default     = []
}

variable "kms_enable_cloudwatch_logs" {
  description = "Enable CloudWatch Logs to use KMS keys for encryption"
  type        = bool
  default     = true
}

variable "kms_enable_grant_permissions" {
  description = "Enable grant creation permissions for key users"
  type        = bool
  default     = true
}

################################################################################
# KMS Configuration - Service-Specific Keys
################################################################################

variable "create_rds_key" {
  description = "Create a dedicated KMS key for RDS encryption"
  type        = bool
  default     = false
}

variable "create_s3_key" {
  description = "Create a dedicated KMS key for S3 encryption"
  type        = bool
  default     = false
}

variable "create_ebs_key" {
  description = "Create a dedicated KMS key for EBS encryption"
  type        = bool
  default     = false
}
