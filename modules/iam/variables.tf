################################################################################
# IAM Module - Variables
# Version: 2.0
# Description: Cross-cutting IAM management (cross-account, org-wide, OIDC)
################################################################################

################################################################################
# IAM Roles Configuration
################################################################################

variable "roles" {
  description = "Map of IAM roles to create"
  type = map(object({
    name                  = string
    description           = optional(string)
    assume_role_policy    = string
    max_session_duration  = optional(number, 3600)
    path                  = optional(string, "/")
    permissions_boundary  = optional(string)
    force_detach_policies = optional(bool, false)
    managed_policy_arns   = optional(list(string), [])
    custom_policy_attachments = optional(list(string), [])
    inline_policies       = optional(map(string), {})
    tags                  = optional(map(string), {})
  }))
  default = {}
}

################################################################################
# IAM Policies Configuration
################################################################################

variable "policies" {
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

################################################################################
# OIDC Providers Configuration
################################################################################

variable "oidc_providers" {
  description = "Map of OIDC identity providers (for GitHub Actions, etc.)"
  type = map(object({
    url             = string
    client_id_list  = list(string)
    thumbprint_list = optional(list(string), [])
    tags            = optional(map(string), {})
  }))
  default = {}
}

################################################################################
# SAML Providers Configuration
################################################################################

variable "saml_providers" {
  description = "Map of SAML identity providers"
  type = map(object({
    name                   = string
    saml_metadata_document = string
    tags                   = optional(map(string), {})
  }))
  default = {}
}

################################################################################
# IAM Groups Configuration
################################################################################

variable "groups" {
  description = "Map of IAM groups to create"
  type = map(object({
    name        = string
    path        = optional(string, "/")
    policy_arns = optional(list(string), [])
  }))
  default = {}
}

################################################################################
# IAM Users Configuration
################################################################################

variable "users" {
  description = "Map of IAM users to create (use SSO instead when possible)"
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

################################################################################
# Account Password Policy
################################################################################

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

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
