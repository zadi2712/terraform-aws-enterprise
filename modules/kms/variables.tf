################################################################################
# KMS Module - Variables
# Version: 2.0
################################################################################

################################################################################
# Required Variables
################################################################################

variable "key_name" {
  description = "Name of the KMS key (used for alias and tags)"
  type        = string
}

variable "description" {
  description = "Description of the KMS key"
  type        = string
}

################################################################################
# Key Configuration
################################################################################

variable "key_usage" {
  description = "Intended use of the key. Valid values: ENCRYPT_DECRYPT, SIGN_VERIFY, GENERATE_VERIFY_MAC"
  type        = string
  default     = "ENCRYPT_DECRYPT"
  
  validation {
    condition     = contains(["ENCRYPT_DECRYPT", "SIGN_VERIFY", "GENERATE_VERIFY_MAC"], var.key_usage)
    error_message = "key_usage must be ENCRYPT_DECRYPT, SIGN_VERIFY, or GENERATE_VERIFY_MAC"
  }
}

variable "customer_master_key_spec" {
  description = "Specifies whether the key contains a symmetric key or an asymmetric key pair"
  type        = string
  default     = "SYMMETRIC_DEFAULT"
  
  validation {
    condition = contains([
      "SYMMETRIC_DEFAULT",
      "RSA_2048",
      "RSA_3072",
      "RSA_4096",
      "ECC_NIST_P256",
      "ECC_NIST_P384",
      "ECC_NIST_P521",
      "ECC_SECG_P256K1",
      "HMAC_224",
      "HMAC_256",
      "HMAC_384",
      "HMAC_512"
    ], var.customer_master_key_spec)
    error_message = "Invalid customer_master_key_spec value"
  }
}

variable "deletion_window_in_days" {
  description = "Duration in days after which the key is deleted after destruction of the resource"
  type        = number
  default     = 30
  
  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30 days"
  }
}

################################################################################
# Key Rotation
################################################################################

variable "enable_key_rotation" {
  description = "Enable automatic key rotation (only for symmetric keys)"
  type        = bool
  default     = true
}

variable "rotation_period_in_days" {
  description = "Custom period of time in days between each rotation"
  type        = number
  default     = 365
  
  validation {
    condition     = var.rotation_period_in_days >= 90 && var.rotation_period_in_days <= 2560
    error_message = "rotation_period_in_days must be between 90 and 2560 days"
  }
}

################################################################################
# Multi-Region Keys
################################################################################

variable "multi_region" {
  description = "Indicates whether the KMS key is a multi-Region (true) or regional (false) key"
  type        = bool
  default     = false
}

variable "replica_regions" {
  description = "Map of replica regions for multi-region keys (requires separate deployment)"
  type        = map(any)
  default     = {}
}

################################################################################
# Key Policy
################################################################################

variable "policy" {
  description = "Custom key policy JSON. If not provided, a default policy will be created"
  type        = string
  default     = null
}

variable "bypass_policy_lockout_safety_check" {
  description = "Bypass the key policy lockout safety check (use with caution)"
  type        = bool
  default     = false
}

variable "key_administrators" {
  description = "List of IAM ARNs that can administer the key"
  type        = list(string)
  default     = []
}

variable "key_users" {
  description = "List of IAM ARNs that can use the key"
  type        = list(string)
  default     = []
}

variable "service_principals" {
  description = "List of AWS service principals that can use the key"
  type        = list(string)
  default     = []
}

variable "via_service_conditions" {
  description = "List of AWS services for kms:ViaService condition"
  type        = list(string)
  default     = []
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch Logs to use this key for encryption"
  type        = bool
  default     = true
}

variable "enable_grant_permissions" {
  description = "Enable grant creation permissions for key users"
  type        = bool
  default     = true
}

################################################################################
# Key Alias
################################################################################

variable "create_alias" {
  description = "Whether to create a key alias"
  type        = bool
  default     = true
}

variable "alias_name" {
  description = "The display name of the alias. Must start with 'alias/'"
  type        = string
  default     = null
  
  validation {
    condition     = var.alias_name == null || can(regex("^alias/", var.alias_name))
    error_message = "alias_name must start with 'alias/'"
  }
}

################################################################################
# Grants
################################################################################

variable "grants" {
  description = "Map of grants to create for the key"
  type = map(object({
    grantee_principal     = string
    operations            = list(string)
    constraints           = optional(map(any))
    retiring_principal    = optional(string)
    grant_creation_tokens = optional(list(string))
    retire_on_delete      = optional(bool, true)
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
