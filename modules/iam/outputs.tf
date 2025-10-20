################################################################################
# IAM Module - Outputs
# Version: 2.0
################################################################################

################################################################################
# Role Outputs
################################################################################

output "role_names" {
  description = "Map of IAM role names"
  value       = { for k, v in aws_iam_role.this : k => v.name }
}

output "role_arns" {
  description = "Map of IAM role ARNs"
  value       = { for k, v in aws_iam_role.this : k => v.arn }
}

output "role_ids" {
  description = "Map of IAM role unique IDs"
  value       = { for k, v in aws_iam_role.this : k => v.unique_id }
}

output "roles" {
  description = "Complete role information"
  value = {
    for k, v in aws_iam_role.this : k => {
      name                 = v.name
      arn                  = v.arn
      id                   = v.id
      unique_id            = v.unique_id
      create_date          = v.create_date
      max_session_duration = v.max_session_duration
    }
  }
}

################################################################################
# Policy Outputs
################################################################################

output "policy_names" {
  description = "Map of IAM policy names"
  value       = { for k, v in aws_iam_policy.this : k => v.name }
}

output "policy_arns" {
  description = "Map of IAM policy ARNs"
  value       = { for k, v in aws_iam_policy.this : k => v.arn }
}

output "policy_ids" {
  description = "Map of IAM policy IDs"
  value       = { for k, v in aws_iam_policy.this : k => v.id }
}

output "policies" {
  description = "Complete policy information"
  value = {
    for k, v in aws_iam_policy.this : k => {
      name        = v.name
      arn         = v.arn
      id          = v.id
      description = v.description
    }
  }
}

################################################################################
# OIDC Provider Outputs
################################################################################

output "oidc_provider_arns" {
  description = "Map of OIDC provider ARNs"
  value       = { for k, v in aws_iam_openid_connect_provider.this : k => v.arn }
}

output "oidc_providers" {
  description = "Complete OIDC provider information"
  value = {
    for k, v in aws_iam_openid_connect_provider.this : k => {
      arn = v.arn
      url = v.url
    }
  }
}

################################################################################
# SAML Provider Outputs
################################################################################

output "saml_provider_arns" {
  description = "Map of SAML provider ARNs"
  value       = { for k, v in aws_iam_saml_provider.this : k => v.arn }
}

output "saml_providers" {
  description = "Complete SAML provider information"
  value = {
    for k, v in aws_iam_saml_provider.this : k => {
      name = v.name
      arn  = v.arn
    }
  }
}

################################################################################
# Group Outputs
################################################################################

output "group_names" {
  description = "Map of IAM group names"
  value       = { for k, v in aws_iam_group.this : k => v.name }
}

output "group_arns" {
  description = "Map of IAM group ARNs"
  value       = { for k, v in aws_iam_group.this : k => v.arn }
}

output "groups" {
  description = "Complete group information"
  value = {
    for k, v in aws_iam_group.this : k => {
      name = v.name
      arn  = v.arn
      id   = v.id
    }
  }
}

################################################################################
# User Outputs
################################################################################

output "user_names" {
  description = "Map of IAM user names"
  value       = { for k, v in aws_iam_user.this : k => v.name }
}

output "user_arns" {
  description = "Map of IAM user ARNs"
  value       = { for k, v in aws_iam_user.this : k => v.arn }
}

output "user_unique_ids" {
  description = "Map of IAM user unique IDs"
  value       = { for k, v in aws_iam_user.this : k => v.unique_id }
}

output "users" {
  description = "Complete user information"
  value = {
    for k, v in aws_iam_user.this : k => {
      name      = v.name
      arn       = v.arn
      unique_id = v.unique_id
    }
  }
}

################################################################################
# Access Key Outputs (Sensitive)
################################################################################

output "access_key_ids" {
  description = "Map of IAM access key IDs"
  value       = { for k, v in aws_iam_access_key.this : k => v.id }
  sensitive   = true
}

output "secret_access_keys" {
  description = "Map of IAM secret access keys"
  value       = { for k, v in aws_iam_access_key.this : k => v.secret }
  sensitive   = true
}

################################################################################
# Summary Output
################################################################################

output "iam_summary" {
  description = "Summary of IAM resources created"
  value = {
    roles_count         = length(aws_iam_role.this)
    policies_count      = length(aws_iam_policy.this)
    oidc_providers_count = length(aws_iam_openid_connect_provider.this)
    saml_providers_count = length(aws_iam_saml_provider.this)
    groups_count        = length(aws_iam_group.this)
    users_count         = length(aws_iam_user.this)
  }
}
