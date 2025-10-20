################################################################################
# Database Layer - RDS, DynamoDB, ElastiCache
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
    tags = merge(var.common_tags, { Layer = "database" })
  }
}

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

data "aws_caller_identity" "current" {}

################################################################################
# RDS Security Group
################################################################################

module "rds_security_group" {
  source = "../../../modules/security-group"

  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  ingress_rules = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = [data.terraform_remote_state.networking.outputs.vpc_cidr]
      description = "Allow PostgreSQL from VPC"
    }
  ]

  tags = var.common_tags
}

################################################################################
# RDS PostgreSQL Instance
################################################################################

module "rds" {
  source = "../../../modules/rds"
  count  = var.create_rds ? 1 : 0

  identifier     = "${var.project_name}-${var.environment}-db"
  engine         = var.rds_engine
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_type

  # Storage configuration
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_type          = var.rds_storage_type
  iops                  = var.rds_iops
  storage_throughput    = var.rds_storage_throughput
  storage_encrypted     = true
  kms_key_id            = try(data.terraform_remote_state.security.outputs.kms_rds_key_arn, data.terraform_remote_state.security.outputs.kms_key_arn, null)

  # Database configuration
  database_name   = var.database_name
  master_username = var.master_username
  master_password = var.rds_manage_master_password ? null : var.master_password
  
  # Managed master password (RDS stores in Secrets Manager)
  manage_master_user_password   = var.rds_manage_master_password
  master_user_secret_kms_key_id = var.rds_manage_master_password ? try(data.terraform_remote_state.security.outputs.kms_key_arn, null) : null

  # Network configuration
  multi_az               = var.enable_multi_az
  db_subnet_group_name   = data.terraform_remote_state.networking.outputs.database_subnet_group_name
  vpc_security_group_ids = [module.rds_security_group.security_group_id]
  publicly_accessible    = var.rds_publicly_accessible

  # Backup configuration
  backup_retention_period = var.backup_retention_days
  backup_window           = var.rds_backup_window
  maintenance_window      = var.rds_maintenance_window
  copy_tags_to_snapshot   = true

  # Monitoring
  enabled_cloudwatch_logs_exports       = var.rds_cloudwatch_logs_exports
  monitoring_interval                   = var.rds_monitoring_interval
  create_monitoring_role                = true
  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_kms_key_id       = var.enable_performance_insights ? try(data.terraform_remote_state.security.outputs.kms_key_arn, null) : null
  performance_insights_retention_period = var.rds_performance_insights_retention_period

  # Upgrades
  auto_minor_version_upgrade  = var.rds_auto_minor_version_upgrade
  allow_major_version_upgrade = var.rds_allow_major_version_upgrade
  apply_immediately           = var.rds_apply_immediately
  enable_blue_green_update    = var.rds_enable_blue_green_update

  # Security
  deletion_protection                 = var.environment == "prod" ? true : var.rds_deletion_protection
  skip_final_snapshot                 = var.environment == "prod" ? false : var.rds_skip_final_snapshot
  iam_database_authentication_enabled = var.rds_iam_authentication_enabled

  # Parameter group
  create_parameter_group = var.rds_create_parameter_group
  parameter_group_family = var.rds_parameter_group_family
  parameters             = var.rds_parameters

  # Option group
  create_option_group  = var.rds_create_option_group
  major_engine_version = var.rds_major_engine_version
  options              = var.rds_options

  # Read replicas
  read_replicas = var.rds_read_replicas

  # Secrets Manager integration
  store_master_password_in_secrets_manager = var.rds_store_password_in_secrets_manager && !var.rds_manage_master_password
  secrets_manager_kms_key_id               = try(data.terraform_remote_state.security.outputs.kms_key_arn, null)

  tags = var.common_tags
}


################################################################################
# Store Outputs in SSM Parameter Store
################################################################################

module "ssm_outputs" {
  source = "../../../modules/ssm-outputs"

  project_name = var.project_name
  environment  = var.environment
  layer_name   = "database"

  outputs = {
    rds_endpoint             = var.create_rds ? module.rds[0].db_instance_endpoint : null
    rds_instance_id          = var.create_rds ? module.rds[0].db_instance_id : null
    rds_security_group_id    = module.rds_security_group.security_group_id
    database_name            = var.create_rds ? var.database_name : null
    master_username          = var.create_rds ? var.master_username : null
  }

  output_descriptions = {
    rds_endpoint          = "RDS PostgreSQL endpoint for database connections"
    rds_instance_id       = "RDS instance identifier"
    rds_security_group_id = "Security group ID for RDS database access"
    database_name         = "Database name"
    master_username       = "Database master username"
  }

  tags = var.common_tags

  depends_on = [
    module.rds,
    module.rds_security_group
  ]
}
