################################################################################
# S3 Module - Variables
# Version: 2.0
################################################################################

################################################################################
# Required Variables
################################################################################

variable "bucket_name" {
  description = "Name of the S3 bucket (must be globally unique)"
  type        = string
}

################################################################################
# Bucket Configuration
################################################################################

variable "force_destroy" {
  description = "Allow bucket deletion even if it contains objects"
  type        = bool
  default     = false
}

################################################################################
# Versioning Configuration
################################################################################

variable "versioning_enabled" {
  description = "Enable versioning"
  type        = bool
  default     = true
}

variable "mfa_delete_enabled" {
  description = "Enable MFA delete (requires bucket versioning)"
  type        = bool
  default     = false
}

################################################################################
# Encryption Configuration
################################################################################

variable "kms_key_id" {
  description = "KMS key ARN for SSE-KMS encryption (null for SSE-S3)"
  type        = string
  default     = null
}

variable "bucket_key_enabled" {
  description = "Enable S3 Bucket Key for reduced KMS costs"
  type        = bool
  default     = true
}

################################################################################
# Public Access Configuration
################################################################################

variable "block_public_access" {
  description = "Block all public access to bucket"
  type        = bool
  default     = true
}

################################################################################
# Bucket Policy
################################################################################

variable "bucket_policy" {
  description = "Custom bucket policy JSON"
  type        = string
  default     = null
}

variable "attach_deny_insecure_transport_policy" {
  description = "Attach policy to deny insecure (non-HTTPS) transport"
  type        = bool
  default     = true
}

################################################################################
# Lifecycle Configuration
################################################################################

variable "lifecycle_rules" {
  description = "List of lifecycle rules"
  type        = list(any)
  default     = []
}

################################################################################
# Intelligent Tiering
################################################################################

variable "intelligent_tiering_configurations" {
  description = "Map of intelligent tiering configurations"
  type = map(object({
    status = optional(string, "Enabled")
    filter = optional(object({
      prefix = optional(string)
      tags   = optional(map(string), {})
    }))
    tierings = list(object({
      access_tier = string
      days        = number
    }))
  }))
  default = {}
}

################################################################################
# CORS Configuration
################################################################################

variable "cors_rules" {
  description = "List of CORS rules"
  type = list(object({
    allowed_methods = list(string)
    allowed_origins = list(string)
    allowed_headers = optional(list(string))
    expose_headers  = optional(list(string))
    max_age_seconds = optional(number)
  }))
  default = []
}

################################################################################
# Logging Configuration
################################################################################

variable "logging_enabled" {
  description = "Enable access logging"
  type        = bool
  default     = false
}

variable "logging_target_bucket" {
  description = "Target bucket for access logs"
  type        = string
  default     = null
}

variable "logging_target_prefix" {
  description = "Prefix for access log objects"
  type        = string
  default     = null
}

################################################################################
# Replication Configuration
################################################################################

variable "replication_enabled" {
  description = "Enable cross-region replication"
  type        = bool
  default     = false
}

variable "create_replication_role" {
  description = "Create IAM role for replication"
  type        = bool
  default     = true
}

variable "replication_role_arn" {
  description = "ARN of existing replication role"
  type        = string
  default     = null
}

variable "replication_rules" {
  description = "Map of replication rules"
  type = map(object({
    status                    = optional(string, "Enabled")
    priority                  = optional(number)
    destination_bucket        = string
    storage_class             = optional(string, "STANDARD")
    replica_kms_key_id        = optional(string)
    delete_marker_replication = optional(bool, false)
    replication_time_enabled  = optional(bool, false)
    metrics_enabled           = optional(bool, false)
    filter = optional(object({
      prefix = optional(string)
    }))
  }))
  default = {}
}

################################################################################
# Object Lock Configuration
################################################################################

variable "object_lock_enabled" {
  description = "Enable object lock (WORM - Write Once Read Many)"
  type        = bool
  default     = false
}

variable "object_lock_mode" {
  description = "Object lock mode (GOVERNANCE or COMPLIANCE)"
  type        = string
  default     = "GOVERNANCE"
  
  validation {
    condition     = var.object_lock_mode == null || contains(["GOVERNANCE", "COMPLIANCE"], var.object_lock_mode)
    error_message = "object_lock_mode must be GOVERNANCE or COMPLIANCE"
  }
}

variable "object_lock_days" {
  description = "Object lock retention in days"
  type        = number
  default     = null
}

variable "object_lock_years" {
  description = "Object lock retention in years"
  type        = number
  default     = null
}

################################################################################
# Website Configuration
################################################################################

variable "website_enabled" {
  description = "Enable static website hosting"
  type        = bool
  default     = false
}

variable "website_index_document" {
  description = "Index document for website"
  type        = string
  default     = "index.html"
}

variable "website_error_document" {
  description = "Error document for website"
  type        = string
  default     = null
}

variable "website_routing_rules" {
  description = "Website routing rules"
  type = list(object({
    condition = object({
      key_prefix_equals               = optional(string)
      http_error_code_returned_equals = optional(string)
    })
    redirect = object({
      host_name               = optional(string)
      http_redirect_code      = optional(string)
      protocol                = optional(string)
      replace_key_prefix_with = optional(string)
      replace_key_with        = optional(string)
    })
  }))
  default = []
}

################################################################################
# Transfer Acceleration
################################################################################

variable "acceleration_status" {
  description = "Transfer acceleration status (Enabled or Suspended)"
  type        = string
  default     = null
  
  validation {
    condition     = var.acceleration_status == null || contains(["Enabled", "Suspended"], var.acceleration_status)
    error_message = "acceleration_status must be Enabled or Suspended"
  }
}

################################################################################
# Request Payment
################################################################################

variable "request_payer" {
  description = "Who pays for requests (BucketOwner or Requester)"
  type        = string
  default     = null
  
  validation {
    condition     = var.request_payer == null || contains(["BucketOwner", "Requester"], var.request_payer)
    error_message = "request_payer must be BucketOwner or Requester"
  }
}

################################################################################
# S3 Analytics
################################################################################

variable "analytics_configurations" {
  description = "Map of S3 analytics configurations"
  type = map(object({
    filter = optional(object({
      prefix = optional(string)
      tags   = optional(map(string), {})
    }))
    storage_class_analysis = optional(object({
      destination_bucket_arn = string
      destination_prefix     = optional(string)
    }))
  }))
  default = {}
}

################################################################################
# S3 Inventory
################################################################################

variable "inventory_configurations" {
  description = "Map of S3 inventory configurations"
  type = map(object({
    included_object_versions = optional(string, "All")
    enabled                  = optional(bool, true)
    frequency                = optional(string, "Weekly")
    destination_bucket_arn   = string
    destination_prefix       = optional(string)
    format                   = optional(string, "CSV")
    optional_fields          = optional(list(string), [])
  }))
  default = {}
}

################################################################################
# S3 Metrics
################################################################################

variable "metrics_configurations" {
  description = "Map of S3 metrics configurations"
  type = map(object({
    filter = optional(object({
      prefix = optional(string)
      tags   = optional(map(string), {})
    }))
  }))
  default = {}
}

################################################################################
# Notifications
################################################################################

variable "enable_notifications" {
  description = "Enable S3 event notifications"
  type        = bool
  default     = false
}

variable "lambda_notifications" {
  description = "Map of Lambda function notifications"
  type = map(object({
    function_arn  = string
    events        = list(string)
    filter_prefix = optional(string)
    filter_suffix = optional(string)
  }))
  default = {}
}

variable "sqs_notifications" {
  description = "Map of SQS queue notifications"
  type = map(object({
    queue_arn     = string
    events        = list(string)
    filter_prefix = optional(string)
    filter_suffix = optional(string)
  }))
  default = {}
}

variable "sns_notifications" {
  description = "Map of SNS topic notifications"
  type = map(object({
    topic_arn     = string
    events        = list(string)
    filter_prefix = optional(string)
    filter_suffix = optional(string)
  }))
  default = {}
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
