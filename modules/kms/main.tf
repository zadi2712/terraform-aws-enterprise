################################################################################
# KMS Module - Enterprise-Grade Encryption Keys
# Version: 2.0
# Description: Comprehensive KMS key management with policies, aliases, and replicas
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  common_tags = merge(
    var.tags,
    {
      Module    = "kms"
      ManagedBy = "terraform"
    }
  )

  # Default key administrators if not provided
  key_administrators = length(var.key_administrators) > 0 ? var.key_administrators : [
    "arn:aws:iam::${local.account_id}:root"
  ]

  # Default key users if not provided
  key_users = length(var.key_users) > 0 ? var.key_users : []

  # Service principals for key usage
  service_principals = length(var.service_principals) > 0 ? var.service_principals : []
}

################################################################################
# KMS Key
################################################################################

resource "aws_kms_key" "this" {
  description              = var.description
  key_usage                = var.key_usage
  customer_master_key_spec = var.customer_master_key_spec
  
  # Rotation
  enable_key_rotation = var.enable_key_rotation && var.key_usage == "ENCRYPT_DECRYPT"
  rotation_period_in_days = var.enable_key_rotation && var.key_usage == "ENCRYPT_DECRYPT" ? var.rotation_period_in_days : null
  
  # Deletion
  deletion_window_in_days = var.deletion_window_in_days
  
  # Multi-region
  multi_region = var.multi_region
  
  # Policy
  policy = var.policy != null ? var.policy : data.aws_iam_policy_document.this.json
  
  # Bypass policy lockout safety check (use with caution)
  bypass_policy_lockout_safety_check = var.bypass_policy_lockout_safety_check

  tags = merge(
    local.common_tags,
    { Name = var.key_name }
  )
}

################################################################################
# Default KMS Key Policy
################################################################################

data "aws_iam_policy_document" "this" {
  # Root account has full control
  statement {
    sid    = "EnableRootAccount"
    effect = "Allow"
    
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
    
    actions = ["kms:*"]
    
    resources = ["*"]
  }

  # Key administrators
  dynamic "statement" {
    for_each = length(local.key_administrators) > 0 ? [1] : []
    
    content {
      sid    = "AllowKeyAdministration"
      effect = "Allow"
      
      principals {
        type        = "AWS"
        identifiers = local.key_administrators
      }
      
      actions = [
        "kms:Create*",
        "kms:Describe*",
        "kms:Enable*",
        "kms:List*",
        "kms:Put*",
        "kms:Update*",
        "kms:Revoke*",
        "kms:Disable*",
        "kms:Get*",
        "kms:Delete*",
        "kms:TagResource",
        "kms:UntagResource",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion"
      ]
      
      resources = ["*"]
    }
  }

  # Key users - encryption and decryption
  dynamic "statement" {
    for_each = length(local.key_users) > 0 ? [1] : []
    
    content {
      sid    = "AllowKeyUsage"
      effect = "Allow"
      
      principals {
        type        = "AWS"
        identifiers = local.key_users
      }
      
      actions = var.key_usage == "ENCRYPT_DECRYPT" ? [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ] : var.key_usage == "SIGN_VERIFY" ? [
        "kms:Sign",
        "kms:Verify",
        "kms:DescribeKey"
      ] : [
        "kms:GenerateMac",
        "kms:VerifyMac",
        "kms:DescribeKey"
      ]
      
      resources = ["*"]
    }
  }

  # Service principals
  dynamic "statement" {
    for_each = length(local.service_principals) > 0 ? [1] : []
    
    content {
      sid    = "AllowServiceUsage"
      effect = "Allow"
      
      principals {
        type        = "Service"
        identifiers = local.service_principals
      }
      
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:CreateGrant",
        "kms:DescribeKey"
      ]
      
      resources = ["*"]
      
      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = var.via_service_conditions
      }
    }
  }

  # Allow CloudWatch Logs
  dynamic "statement" {
    for_each = var.enable_cloudwatch_logs ? [1] : []
    
    content {
      sid    = "AllowCloudWatchLogs"
      effect = "Allow"
      
      principals {
        type        = "Service"
        identifiers = ["logs.${local.region}.amazonaws.com"]
      }
      
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:CreateGrant",
        "kms:DescribeKey"
      ]
      
      resources = ["*"]
      
      condition {
        test     = "ArnLike"
        variable = "kms:EncryptionContext:aws:logs:arn"
        values   = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:*"]
      }
    }
  }

  # Grant permissions for attachment of persistent resources
  dynamic "statement" {
    for_each = var.enable_grant_permissions ? [1] : []
    
    content {
      sid    = "AllowGrantCreation"
      effect = "Allow"
      
      principals {
        type        = "AWS"
        identifiers = concat(local.key_users, local.key_administrators)
      }
      
      actions = [
        "kms:CreateGrant",
        "kms:ListGrants",
        "kms:RevokeGrant"
      ]
      
      resources = ["*"]
      
      condition {
        test     = "Bool"
        variable = "kms:GrantIsForAWSResource"
        values   = ["true"]
      }
    }
  }
}

################################################################################
# KMS Key Alias
################################################################################

resource "aws_kms_alias" "this" {
  count = var.create_alias ? 1 : 0
  
  name          = var.alias_name != null ? var.alias_name : "alias/${var.key_name}"
  target_key_id = aws_kms_key.this.key_id
}

################################################################################
# KMS Replica Keys (Multi-Region)
# Note: Replica keys require separate terraform deployments in each region
# This is a placeholder for multi-region key support
# To use multi-region keys: Set multi_region = true and deploy replicas separately
################################################################################

# Multi-region keys are created with multi_region = true
# Replicas must be created in other regions using aws_kms_replica_key
# in a separate terraform deployment with appropriate provider configuration

################################################################################
# KMS Grants
################################################################################

resource "aws_kms_grant" "this" {
  for_each = var.grants
  
  name              = each.key
  key_id            = aws_kms_key.this.key_id
  grantee_principal = each.value.grantee_principal
  operations        = each.value.operations
  
  dynamic "constraints" {
    for_each = each.value.constraints != null ? [each.value.constraints] : []
    
    content {
      encryption_context_equals = lookup(constraints.value, "encryption_context_equals", null)
      encryption_context_subset = lookup(constraints.value, "encryption_context_subset", null)
    }
  }
  
  retiring_principal    = lookup(each.value, "retiring_principal", null)
  grant_creation_tokens = lookup(each.value, "grant_creation_tokens", null)
  retire_on_delete      = lookup(each.value, "retire_on_delete", true)
}
