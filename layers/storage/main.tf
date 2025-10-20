################################################################################
# Storage Layer - S3, EFS
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
    tags = merge(var.common_tags, { Layer = "storage" })
  }
}

data "aws_caller_identity" "current" {}

# Data sources for networking
data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "terraform-state-${var.environment}-${data.aws_caller_identity.current.account_id}"
    key    = "layers/networking/${var.environment}/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket = "terraform-state-${var.environment}-${data.aws_caller_identity.current.account_id}"
    key    = "layers/security/${var.environment}/terraform.tfstate"
    region = var.aws_region
  }
}

################################################################################
# S3 Buckets
################################################################################

module "application_bucket" {
  source = "../../../modules/s3"

  bucket_name        = "${var.project_name}-${var.environment}-app-${data.aws_caller_identity.current.account_id}"
  versioning_enabled = var.s3_app_versioning_enabled
  force_destroy      = var.environment != "prod" ? var.s3_force_destroy : false

  # Encryption
  kms_key_id         = var.s3_enable_kms_encryption ? try(data.terraform_remote_state.security.outputs.kms_s3_key_arn, data.terraform_remote_state.security.outputs.kms_key_arn, null) : null
  bucket_key_enabled = var.s3_enable_kms_encryption

  # Security
  block_public_access                   = true
  attach_deny_insecure_transport_policy = true

  # Lifecycle management
  lifecycle_rules = var.s3_app_lifecycle_rules

  # Intelligent Tiering (optional)
  intelligent_tiering_configurations = var.s3_app_intelligent_tiering

  # Replication (optional)
  replication_enabled = var.s3_app_replication_enabled
  replication_rules   = var.s3_app_replication_rules

  # Logging (optional)
  logging_enabled       = var.s3_enable_access_logging
  logging_target_bucket = var.s3_enable_access_logging ? module.logs_bucket.bucket_id : null
  logging_target_prefix = "s3-access/application/"

  tags = merge(var.common_tags, {
    BucketType = "application"
  })
}

module "logs_bucket" {
  source = "../../../modules/s3"

  bucket_name        = "${var.project_name}-${var.environment}-logs-${data.aws_caller_identity.current.account_id}"
  versioning_enabled = false  # Not needed for logs
  force_destroy      = var.environment != "prod" ? var.s3_force_destroy : false

  # Encryption
  kms_key_id         = var.s3_enable_kms_encryption ? try(data.terraform_remote_state.security.outputs.kms_s3_key_arn, data.terraform_remote_state.security.outputs.kms_key_arn, null) : null
  bucket_key_enabled = var.s3_enable_kms_encryption

  # Security
  block_public_access                   = true
  attach_deny_insecure_transport_policy = true

  # Lifecycle - expire logs after retention period
  lifecycle_rules = [
    {
      id      = "expire-old-logs"
      enabled = true
      
      transitions = var.s3_logs_lifecycle_enabled ? [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ] : []
      
      expiration = {
        days = var.logs_retention_days
      }
    }
  ]

  # Intelligent Tiering for logs (optional)
  intelligent_tiering_configurations = var.s3_logs_intelligent_tiering_enabled ? {
    logs = {
      tierings = [
        {
          access_tier = "ARCHIVE_ACCESS"
          days        = 90
        }
      ]
    }
  } : {}

  tags = merge(var.common_tags, {
    BucketType = "logs"
  })
}

################################################################################
# EFS File Systems
################################################################################

# Security Group for EFS
module "efs_security_group" {
  source = "../../../modules/security-group"
  count  = var.enable_efs ? 1 : 0

  name        = "${var.project_name}-${var.environment}-efs-sg"
  description = "Security group for EFS mount targets"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  ingress_rules = [
    {
      from_port   = 2049
      to_port     = 2049
      protocol    = "tcp"
      cidr_blocks = [data.terraform_remote_state.networking.outputs.vpc_cidr_block]
      description = "Allow NFS from VPC"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]

  tags = var.common_tags
}

# EFS File System
module "efs" {
  source = "../../../modules/efs"
  count  = var.enable_efs ? 1 : 0

  name             = "${var.project_name}-${var.environment}-efs"
  creation_token   = "${var.project_name}-${var.environment}-${data.aws_caller_identity.current.account_id}"
  performance_mode = var.efs_performance_mode
  throughput_mode  = var.efs_throughput_mode
  
  # Provisioned throughput (if applicable)
  provisioned_throughput_in_mibps = var.efs_throughput_mode == "provisioned" ? var.efs_provisioned_throughput : null

  # One Zone configuration (if applicable)
  availability_zone_name = var.efs_availability_zone_name

  # Encryption
  encrypted  = var.efs_encrypted
  kms_key_id = var.efs_encrypted ? try(data.terraform_remote_state.security.outputs.kms_key_arn, null) : null

  # Lifecycle management
  transition_to_ia                    = var.efs_transition_to_ia
  transition_to_primary_storage_class = var.efs_transition_to_primary_storage_class

  # Network configuration
  create_mount_targets = var.efs_create_mount_targets
  subnet_ids           = var.efs_create_mount_targets ? data.terraform_remote_state.networking.outputs.private_subnet_ids : []
  security_group_ids   = var.efs_create_mount_targets ? [module.efs_security_group[0].security_group_id] : []

  # Backup
  enable_backup_policy = var.efs_enable_backup_policy

  # Access points
  access_points = var.efs_access_points

  # File system policy
  file_system_policy = var.efs_file_system_policy

  # Replication
  enable_replication                      = var.efs_enable_replication
  replication_destination_region          = var.efs_replication_destination_region
  replication_destination_availability_zone = var.efs_replication_destination_availability_zone
  replication_destination_kms_key_id      = var.efs_replication_destination_kms_key_id

  tags = var.common_tags
}


################################################################################
# Store Outputs in SSM Parameter Store
################################################################################

module "ssm_outputs" {
  source = "../../../modules/ssm-outputs"

  project_name = var.project_name
  environment  = var.environment
  layer_name   = "storage"

  outputs = {
    # S3 Buckets
    application_bucket_id   = module.application_bucket.bucket_id
    application_bucket_arn  = module.application_bucket.bucket_arn
    application_bucket_name = module.application_bucket.bucket_id
    logs_bucket_id          = module.logs_bucket.bucket_id
    logs_bucket_arn         = module.logs_bucket.bucket_arn
    logs_bucket_name        = module.logs_bucket.bucket_id
    
    # EFS File Systems
    efs_file_system_id       = var.enable_efs ? module.efs[0].file_system_id : null
    efs_file_system_arn      = var.enable_efs ? module.efs[0].file_system_arn : null
    efs_dns_name             = var.enable_efs ? module.efs[0].file_system_dns_name : null
    efs_security_group_id    = var.enable_efs ? module.efs_security_group[0].security_group_id : null
    efs_access_point_ids     = var.enable_efs ? jsonencode(module.efs[0].access_point_ids) : null
  }

  output_descriptions = {
    application_bucket_id   = "Application S3 bucket ID"
    application_bucket_arn  = "Application S3 bucket ARN"
    application_bucket_name = "Application S3 bucket name"
    logs_bucket_id          = "Logs S3 bucket ID"
    logs_bucket_arn         = "Logs S3 bucket ARN"
    logs_bucket_name        = "Logs S3 bucket name"
    efs_file_system_id      = "EFS file system ID"
    efs_file_system_arn     = "EFS file system ARN"
    efs_dns_name            = "EFS DNS name for mounting"
    efs_security_group_id   = "EFS security group ID"
    efs_access_point_ids    = "EFS access point IDs (JSON)"
  }

  tags = var.common_tags

  depends_on = [
    module.application_bucket,
    module.logs_bucket,
    module.efs
  ]
}
