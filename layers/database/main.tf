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
  engine         = "postgres"
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_type

  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_encrypted     = true

  database_name   = var.database_name
  master_username = var.master_username
  master_password = var.master_password

  multi_az               = var.enable_multi_az
  db_subnet_group_name   = data.terraform_remote_state.networking.outputs.database_subnet_group_name
  vpc_security_group_ids = [module.rds_security_group.security_group_id]

  backup_retention_period = var.backup_retention_days
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = var.enable_performance_insights

  deletion_protection = var.environment == "prod"
  skip_final_snapshot = var.environment != "prod"

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
