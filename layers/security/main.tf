################################################################################
# Security Layer - IAM, KMS, Secrets Manager
################################################################################

terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = merge(var.common_tags, { Layer = "security" })
  }
}

################################################################################
# KMS Keys
################################################################################

# Main encryption key for general purpose encryption
module "kms_main" {
  source = "../../../modules/kms"

  key_name    = "${var.project_name}-${var.environment}-main"
  description = var.kms_main_description

  # Key configuration
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  deletion_window_in_days  = var.kms_deletion_window_in_days

  # Rotation
  enable_key_rotation     = var.kms_enable_key_rotation
  rotation_period_in_days = var.kms_rotation_period_in_days

  # Access control
  key_administrators = var.kms_key_administrators
  key_users          = var.kms_key_users

  # Service principals
  service_principals     = var.kms_service_principals
  via_service_conditions = var.kms_via_service_conditions

  # CloudWatch Logs
  enable_cloudwatch_logs = var.kms_enable_cloudwatch_logs

  # Grant permissions
  enable_grant_permissions = var.kms_enable_grant_permissions

  # Alias
  create_alias = true
  alias_name   = "alias/${var.project_name}/${var.environment}/main"

  tags = var.common_tags
}

# Additional KMS keys for specific services (optional)
module "kms_rds" {
  source = "../../../modules/kms"
  count  = var.create_rds_key ? 1 : 0

  key_name    = "${var.project_name}-${var.environment}-rds"
  description = "Encryption key for RDS databases"

  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true

  key_administrators = var.kms_key_administrators
  key_users          = concat(var.kms_key_users, [data.aws_caller_identity.current.arn])

  service_principals = ["rds.amazonaws.com"]
  via_service_conditions = [
    "rds.${var.aws_region}.amazonaws.com"
  ]

  enable_grant_permissions = true
  enable_cloudwatch_logs   = true

  create_alias = true
  alias_name   = "alias/${var.project_name}/${var.environment}/rds"

  tags = merge(var.common_tags, {
    Service = "rds"
  })
}

module "kms_s3" {
  source = "../../../modules/kms"
  count  = var.create_s3_key ? 1 : 0

  key_name    = "${var.project_name}-${var.environment}-s3"
  description = "Encryption key for S3 buckets"

  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true

  key_administrators = var.kms_key_administrators
  key_users          = concat(var.kms_key_users, [data.aws_caller_identity.current.arn])

  service_principals = ["s3.amazonaws.com"]
  via_service_conditions = [
    "s3.${var.aws_region}.amazonaws.com"
  ]

  enable_grant_permissions = true
  enable_cloudwatch_logs   = true

  create_alias = true
  alias_name   = "alias/${var.project_name}/${var.environment}/s3"

  tags = merge(var.common_tags, {
    Service = "s3"
  })
}

module "kms_ebs" {
  source = "../../../modules/kms"
  count  = var.create_ebs_key ? 1 : 0

  key_name    = "${var.project_name}-${var.environment}-ebs"
  description = "Default encryption key for EBS volumes"

  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true

  key_administrators = var.kms_key_administrators
  key_users          = concat(var.kms_key_users, [data.aws_caller_identity.current.arn])

  service_principals = ["ec2.amazonaws.com"]
  via_service_conditions = [
    "ec2.${var.aws_region}.amazonaws.com"
  ]

  enable_grant_permissions = true
  enable_cloudwatch_logs   = true

  create_alias = true
  alias_name   = "alias/${var.project_name}/${var.environment}/ebs"

  tags = merge(var.common_tags, {
    Service = "ebs"
  })
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

################################################################################
# Store Outputs in SSM Parameter Store
################################################################################

module "ssm_outputs" {
  source = "../../../modules/ssm-outputs"

  project_name = var.project_name
  environment  = var.environment
  layer_name   = "security"

  outputs = {
    # Main KMS key
    kms_key_id           = module.kms_main.key_id
    kms_key_arn          = module.kms_main.key_arn
    kms_key_alias_name   = module.kms_main.key_alias_name
    kms_key_alias_arn    = module.kms_main.key_alias_arn
    
    # RDS KMS key
    kms_rds_key_id       = var.create_rds_key ? module.kms_rds[0].key_id : null
    kms_rds_key_arn      = var.create_rds_key ? module.kms_rds[0].key_arn : null
    
    # S3 KMS key
    kms_s3_key_id        = var.create_s3_key ? module.kms_s3[0].key_id : null
    kms_s3_key_arn       = var.create_s3_key ? module.kms_s3[0].key_arn : null
    
    # EBS KMS key
    kms_ebs_key_id       = var.create_ebs_key ? module.kms_ebs[0].key_id : null
    kms_ebs_key_arn      = var.create_ebs_key ? module.kms_ebs[0].key_arn : null
  }

  output_descriptions = {
    kms_key_id           = "Main KMS key ID for encryption"
    kms_key_arn          = "Main KMS key ARN for encryption"
    kms_key_alias_name   = "Main KMS key alias name"
    kms_key_alias_arn    = "Main KMS key alias ARN"
    kms_rds_key_id       = "RDS KMS key ID"
    kms_rds_key_arn      = "RDS KMS key ARN"
    kms_s3_key_id        = "S3 KMS key ID"
    kms_s3_key_arn       = "S3 KMS key ARN"
    kms_ebs_key_id       = "EBS KMS key ID"
    kms_ebs_key_arn      = "EBS KMS key ARN"
  }

  tags = var.common_tags

  depends_on = [
    module.kms_main,
    module.kms_rds,
    module.kms_s3,
    module.kms_ebs
  ]
}
