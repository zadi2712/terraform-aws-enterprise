################################################################################
# ECR Module Variables
################################################################################

variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "image_tag_mutability" {
  description = "The tag mutability setting for the repository. Must be one of: MUTABLE or IMMUTABLE"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be either MUTABLE or IMMUTABLE."
  }
}

################################################################################
# Encryption Configuration
################################################################################

variable "encryption_type" {
  description = "The encryption type to use for the repository. Valid values are AES256 or KMS"
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "encryption_type must be either AES256 or KMS."
  }
}

variable "kms_key_arn" {
  description = "The ARN of the KMS key to use when encryption_type is KMS"
  type        = string
  default     = null
}

################################################################################
# Image Scanning Configuration
################################################################################

variable "scan_on_push" {
  description = "Indicates whether images are scanned after being pushed to the repository"
  type        = bool
  default     = true
}

variable "enable_enhanced_scanning" {
  description = "Enable enhanced scanning for continuous vulnerability scanning"
  type        = bool
  default     = false
}

variable "scan_frequency" {
  description = "Scan frequency for enhanced scanning (SCAN_ON_PUSH, CONTINUOUS_SCAN, or MANUAL)"
  type        = string
  default     = "SCAN_ON_PUSH"
}

variable "enable_scan_findings_logging" {
  description = "Enable CloudWatch logging for image scan findings"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Number of days to retain scan findings logs"
  type        = number
  default     = 30
}

################################################################################
# Lifecycle Policy Configuration
################################################################################

variable "lifecycle_policy" {
  description = "ECR lifecycle policy as a JSON string. If null, a default policy will be created"
  type        = string
  default     = null
}

variable "max_image_count" {
  description = "Maximum number of images to keep (used in default lifecycle policy)"
  type        = number
  default     = 100
}

################################################################################
# Repository Policy Configuration
################################################################################

variable "repository_policy" {
  description = "ECR repository policy as a JSON string"
  type        = string
  default     = null
}

variable "enable_cross_account_access" {
  description = "Enable cross-account access to the repository"
  type        = bool
  default     = false
}

variable "allowed_account_ids" {
  description = "List of AWS account IDs allowed to pull images (when enable_cross_account_access is true)"
  type        = list(string)
  default     = []
}

variable "enable_lambda_pull" {
  description = "Enable Lambda service to pull images from this repository"
  type        = bool
  default     = false
}

variable "registry_policy" {
  description = "Registry-level policy as a JSON string"
  type        = string
  default     = null
}

################################################################################
# Replication Configuration
################################################################################

variable "enable_replication" {
  description = "Enable ECR replication"
  type        = bool
  default     = false
}

variable "replication_destinations" {
  description = "List of replication destinations"
  type = list(object({
    region      = string
    registry_id = string
  }))
  default = []
}

################################################################################
# Pull Through Cache Configuration
################################################################################

variable "enable_pull_through_cache" {
  description = "Enable pull through cache for public registries"
  type        = bool
  default     = false
}

variable "pull_through_cache_prefix" {
  description = "ECR repository prefix for pull through cache"
  type        = string
  default     = "ecr-public"
}

variable "upstream_registry_url" {
  description = "Upstream registry URL for pull through cache (e.g., public.ecr.aws or registry-1.docker.io)"
  type        = string
  default     = "public.ecr.aws"
}

variable "pull_through_cache_credential_arn" {
  description = "ARN of Secrets Manager secret containing credentials for upstream registry"
  type        = string
  default     = null
}

################################################################################
# General Configuration
################################################################################

variable "force_delete" {
  description = "If true, will delete the repository even if it contains images"
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
