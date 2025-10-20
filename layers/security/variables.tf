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

################################################################################
# IAM Configuration - Cross-Cutting Concerns
################################################################################

variable "enable_cross_account_roles" {
  description = "Enable cross-account IAM roles"
  type        = bool
  default     = false
}

variable "enable_oidc_providers" {
  description = "Enable OIDC providers (GitHub Actions, etc.)"
  type        = bool
  default     = false
}

variable "enable_iam_groups" {
  description = "Enable IAM groups and users"
  type        = bool
  default     = false
}

variable "iam_roles" {
  description = "Map of IAM roles to create (cross-account, org-wide only)"
  type = map(object({
    name                      = string
    description               = optional(string)
    assume_role_policy        = string
    max_session_duration      = optional(number, 3600)
    path                      = optional(string, "/")
    permissions_boundary      = optional(string)
    force_detach_policies     = optional(bool, false)
    managed_policy_arns       = optional(list(string), [])
    custom_policy_attachments = optional(list(string), [])
    inline_policies           = optional(map(string), {})
    tags                      = optional(map(string), {})
  }))
  default = {}
}

variable "iam_policies" {
  description = "Map of custom IAM policies to create"
  type = map(object({
    name        = string
    description = optional(string)
    policy      = string
    path        = optional(string, "/")
    tags        = optional(map(string), {})
  }))
  default = {}
}

variable "oidc_providers" {
  description = "Map of OIDC identity providers"
  type = map(object({
    url             = string
    client_id_list  = list(string)
    thumbprint_list = optional(list(string), [])
    tags            = optional(map(string), {})
  }))
  default = {}
}

variable "saml_providers" {
  description = "Map of SAML identity providers"
  type = map(object({
    name                   = string
    saml_metadata_document = string
    tags                   = optional(map(string), {})
  }))
  default = {}
}

variable "iam_groups" {
  description = "Map of IAM groups to create"
  type = map(object({
    name        = string
    path        = optional(string, "/")
    policy_arns = optional(list(string), [])
  }))
  default = {}
}

variable "iam_users" {
  description = "Map of IAM users to create (prefer SSO)"
  type = map(object({
    name                 = string
    path                 = optional(string, "/")
    permissions_boundary = optional(string)
    force_destroy        = optional(bool, false)
    groups               = optional(list(string), [])
    policy_arns          = optional(list(string), [])
    create_access_key    = optional(bool, false)
    tags                 = optional(map(string), {})
  }))
  default = {}
}

variable "configure_password_policy" {
  description = "Whether to configure IAM account password policy"
  type        = bool
  default     = false
}

variable "password_policy" {
  description = "IAM account password policy configuration"
  type = object({
    minimum_password_length        = optional(number, 14)
    require_lowercase_characters   = optional(bool, true)
    require_numbers                = optional(bool, true)
    require_uppercase_characters   = optional(bool, true)
    require_symbols                = optional(bool, true)
    allow_users_to_change_password = optional(bool, true)
    max_password_age               = optional(number, 90)
    password_reuse_prevention      = optional(number, 24)
    hard_expiry                    = optional(bool, false)
  })
  default = {
    minimum_password_length        = 14
    require_lowercase_characters   = true
    require_numbers                = true
    require_uppercase_characters   = true
    require_symbols                = true
    allow_users_to_change_password = true
    max_password_age               = 90
    password_reuse_prevention      = 24
    hard_expiry                    = false
  }
}
