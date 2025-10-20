################################################################################
# IAM Module - Cross-Cutting IAM Management
# Version: 2.0
# Description: Organization-wide IAM roles, policies, and OIDC providers
# Note: Service-specific IAM should be module-owned (see ARCHITECTURE_DECISION_IAM.md)
################################################################################

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  common_tags = merge(
    var.tags,
    {
      Module    = "iam"
      ManagedBy = "terraform"
    }
  )
}

################################################################################
# IAM Roles
################################################################################

resource "aws_iam_role" "this" {
  for_each = var.roles

  name                 = each.value.name
  description          = lookup(each.value, "description", null)
  assume_role_policy   = each.value.assume_role_policy
  max_session_duration = lookup(each.value, "max_session_duration", 3600)
  path                 = lookup(each.value, "path", "/")
  permissions_boundary = lookup(each.value, "permissions_boundary", null)
  force_detach_policies = lookup(each.value, "force_detach_policies", false)

  tags = merge(
    local.common_tags,
    lookup(each.value, "tags", {})
  )
}

################################################################################
# IAM Role Policy Attachments - Managed Policies
################################################################################

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = {
    for item in flatten([
      for role_key, role in var.roles : [
        for policy_arn in lookup(role, "managed_policy_arns", []) : {
          role_key   = role_key
          policy_arn = policy_arn
          key        = "${role_key}-${replace(policy_arn, "/[^a-zA-Z0-9]/", "-")}"
        }
      ]
    ]) : item.key => item
  }

  role       = aws_iam_role.this[each.value.role_key].name
  policy_arn = each.value.policy_arn
}

################################################################################
# IAM Policies - Custom
################################################################################

resource "aws_iam_policy" "this" {
  for_each = var.policies

  name        = each.value.name
  description = lookup(each.value, "description", null)
  policy      = each.value.policy
  path        = lookup(each.value, "path", "/")

  tags = merge(
    local.common_tags,
    lookup(each.value, "tags", {})
  )
}

################################################################################
# IAM Role Policy Attachments - Custom Policies
################################################################################

resource "aws_iam_role_policy_attachment" "custom" {
  for_each = {
    for item in flatten([
      for role_key, role in var.roles : [
        for policy_key in lookup(role, "custom_policy_attachments", []) : {
          role_key   = role_key
          policy_key = policy_key
          key        = "${role_key}-${policy_key}"
        }
      ]
    ]) : item.key => item
  }

  role       = aws_iam_role.this[each.value.role_key].name
  policy_arn = aws_iam_policy.this[each.value.policy_key].arn

  depends_on = [
    aws_iam_role.this,
    aws_iam_policy.this
  ]
}

################################################################################
# IAM Inline Policies
################################################################################

resource "aws_iam_role_policy" "inline" {
  for_each = {
    for item in flatten([
      for role_key, role in var.roles : [
        for policy_name, policy_document in lookup(role, "inline_policies", {}) : {
          role_key = role_key
          name     = policy_name
          policy   = policy_document
          key      = "${role_key}-${policy_name}"
        }
      ]
    ]) : item.key => item
  }

  name   = each.value.name
  role   = aws_iam_role.this[each.value.role_key].id
  policy = each.value.policy
}

################################################################################
# OIDC Identity Providers (for GitHub Actions, etc.)
################################################################################

resource "aws_iam_openid_connect_provider" "this" {
  for_each = var.oidc_providers

  url             = each.value.url
  client_id_list  = each.value.client_id_list
  thumbprint_list = lookup(each.value, "thumbprint_list", [])

  tags = merge(
    local.common_tags,
    lookup(each.value, "tags", {})
  )
}

################################################################################
# SAML Identity Providers
################################################################################

resource "aws_iam_saml_provider" "this" {
  for_each = var.saml_providers

  name                   = each.value.name
  saml_metadata_document = each.value.saml_metadata_document

  tags = merge(
    local.common_tags,
    lookup(each.value, "tags", {})
  )
}

################################################################################
# IAM Groups
################################################################################

resource "aws_iam_group" "this" {
  for_each = var.groups

  name = each.value.name
  path = lookup(each.value, "path", "/")
}

resource "aws_iam_group_policy_attachment" "this" {
  for_each = {
    for item in flatten([
      for group_key, group in var.groups : [
        for policy_arn in lookup(group, "policy_arns", []) : {
          group_key  = group_key
          policy_arn = policy_arn
          key        = "${group_key}-${replace(policy_arn, "/[^a-zA-Z0-9]/", "-")}"
        }
      ]
    ]) : item.key => item
  }

  group      = aws_iam_group.this[each.value.group_key].name
  policy_arn = each.value.policy_arn
}

################################################################################
# IAM Users (Optional - for human access)
################################################################################

resource "aws_iam_user" "this" {
  for_each = var.users

  name                 = each.value.name
  path                 = lookup(each.value, "path", "/")
  permissions_boundary = lookup(each.value, "permissions_boundary", null)
  force_destroy        = lookup(each.value, "force_destroy", false)

  tags = merge(
    local.common_tags,
    lookup(each.value, "tags", {})
  )
}

resource "aws_iam_user_group_membership" "this" {
  for_each = {
    for user_key, user in var.users : user_key => user
    if length(lookup(user, "groups", [])) > 0
  }

  user   = aws_iam_user.this[each.key].name
  groups = each.value.groups
}

resource "aws_iam_user_policy_attachment" "this" {
  for_each = {
    for item in flatten([
      for user_key, user in var.users : [
        for policy_arn in lookup(user, "policy_arns", []) : {
          user_key   = user_key
          policy_arn = policy_arn
          key        = "${user_key}-${replace(policy_arn, "/[^a-zA-Z0-9]/", "-")}"
        }
      ]
    ]) : item.key => item
  }

  user       = aws_iam_user.this[each.value.user_key].name
  policy_arn = each.value.policy_arn
}

################################################################################
# IAM Access Keys (for programmatic access)
################################################################################

resource "aws_iam_access_key" "this" {
  for_each = {
    for user_key, user in var.users : user_key => user
    if lookup(user, "create_access_key", false)
  }

  user = aws_iam_user.this[each.key].name
}

################################################################################
# IAM Account Settings
################################################################################

resource "aws_iam_account_password_policy" "this" {
  count = var.configure_password_policy ? 1 : 0

  minimum_password_length        = var.password_policy.minimum_password_length
  require_lowercase_characters   = var.password_policy.require_lowercase_characters
  require_numbers                = var.password_policy.require_numbers
  require_uppercase_characters   = var.password_policy.require_uppercase_characters
  require_symbols                = var.password_policy.require_symbols
  allow_users_to_change_password = var.password_policy.allow_users_to_change_password
  max_password_age               = var.password_policy.max_password_age
  password_reuse_prevention      = var.password_policy.password_reuse_prevention
  hard_expiry                    = var.password_policy.hard_expiry
}
