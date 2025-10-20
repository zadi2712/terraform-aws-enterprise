#!/usr/bin/env python3
"""
Generate all layer configurations (main.tf, variables.tf, outputs.tf, versions.tf)
"""

import os
from pathlib import Path

BASE_DIR = "/Users/diego/terraform-aws-enterprise"

LAYERS_CONFIG = {
    "compute": {
        "main.tf": '''################################################################################
# Compute Layer - EC2, ECS, Lambda
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
    tags = merge(var.common_tags, { Layer = "compute" })
  }
}

# Data source to get networking outputs
data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "terraform-state-${var.environment}-${data.aws_caller_identity.current.account_id}"
    key    = "layers/networking/${var.environment}/terraform.tfstate"
    region = var.aws_region
  }
}

data "aws_caller_identity" "current" {}

################################################################################
# ECS Cluster
################################################################################

module "ecs_cluster" {
  source = "../../../modules/ecs"

  cluster_name                = "${var.project_name}-${var.environment}-cluster"
  container_insights_enabled  = var.enable_container_insights

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy = [
    {
      capacity_provider = "FARGATE"
      weight            = 1
      base              = 1
    }
  ]

  tags = var.common_tags
}

################################################################################
# Application Load Balancer Security Group
################################################################################

module "alb_security_group" {
  source = "../../../modules/security-group"

  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTP from anywhere"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTPS from anywhere"
    }
  ]

  tags = var.common_tags
}
''',
        "variables.tf": '''variable "environment" {
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

variable "enable_container_insights" {
  description = "Enable ECS Container Insights"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
''',
        "outputs.tf": '''output "ecs_cluster_id" {
  description = "ECS Cluster ID"
  value       = module.ecs_cluster.cluster_id
}

output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = module.ecs_cluster.cluster_name
}

output "alb_security_group_id" {
  description = "ALB Security Group ID"
  value       = module.alb_security_group.security_group_id
}
''',
        "versions.tf": '''terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
'''
    },
    
    "database": {
        "main.tf": '''################################################################################
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
''',
        "variables.tf": '''variable "environment" {
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

variable "create_rds" {
  description = "Create RDS instance"
  type        = bool
  default     = true
}

variable "rds_engine_version" {
  description = "RDS engine version"
  type        = string
  default     = "15.4"
}

variable "rds_instance_type" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.small"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "Max allocated storage"
  type        = number
  default     = 100
}

variable "database_name" {
  description = "Database name"
  type        = string
  default     = "appdb"
}

variable "master_username" {
  description = "Master username"
  type        = string
  default     = "dbadmin"
}

variable "master_password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

variable "enable_multi_az" {
  description = "Enable Multi-AZ"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Backup retention in days"
  type        = number
  default     = 7
}

variable "enable_performance_insights" {
  description = "Enable Performance Insights"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
''',
        "outputs.tf": '''output "rds_endpoint" {
  description = "RDS endpoint"
  value       = var.create_rds ? module.rds[0].db_instance_endpoint : null
}

output "rds_instance_id" {
  description = "RDS instance ID"
  value       = var.create_rds ? module.rds[0].db_instance_id : null
}
''',
        "versions.tf": '''terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
'''
    },
    
    "storage": {
        "main.tf": '''################################################################################
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

################################################################################
# S3 Buckets
################################################################################

module "application_bucket" {
  source = "../../../modules/s3"

  bucket_name        = "${var.project_name}-${var.environment}-app-${data.aws_caller_identity.current.account_id}"
  versioning_enabled = true

  lifecycle_rules = [
    {
      id      = "transition-to-ia"
      enabled = true
      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]
    }
  ]

  tags = var.common_tags
}

module "logs_bucket" {
  source = "../../../modules/s3"

  bucket_name        = "${var.project_name}-${var.environment}-logs-${data.aws_caller_identity.current.account_id}"
  versioning_enabled = true

  lifecycle_rules = [
    {
      id      = "expire-old-logs"
      enabled = true
      expiration = {
        days = var.logs_retention_days
      }
    }
  ]

  tags = var.common_tags
}
''',
        "variables.tf": '''variable "environment" {
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

variable "logs_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 90
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
''',
        "outputs.tf": '''output "application_bucket_id" {
  description = "Application bucket ID"
  value       = module.application_bucket.bucket_id
}

output "logs_bucket_id" {
  description = "Logs bucket ID"
  value       = module.logs_bucket.bucket_id
}
''',
        "versions.tf": '''terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
'''
    },
    
    "security": {
        "main.tf": '''################################################################################
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

resource "aws_kms_key" "main" {
  description             = "Main encryption key for ${var.environment}"
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  enable_key_rotation     = true

  tags = merge(var.common_tags, { Name = "${var.project_name}-${var.environment}-key" })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}-${var.environment}"
  target_key_id = aws_kms_key.main.key_id
}

################################################################################
# IAM Roles
################################################################################

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
''',
        "variables.tf": '''variable "environment" {
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
''',
        "outputs.tf": '''output "kms_key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.main.id
}

output "kms_key_arn" {
  description = "KMS key ARN"
  value       = aws_kms_key.main.arn
}

output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = aws_iam_role.ecs_task_execution.arn
}
''',
        "versions.tf": '''terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
'''
    },
    
    "dns": {
        "main.tf": '''################################################################################
# DNS Layer - Route53
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
    tags = merge(var.common_tags, { Layer = "dns" })
  }
}

################################################################################
# Route53 Hosted Zone (if domain_name is provided)
################################################################################

resource "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0

  name = var.domain_name

  tags = merge(var.common_tags, { Name = var.domain_name })
}
''',
        "variables.tf": '''variable "environment" {
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

variable "domain_name" {
  description = "Domain name for Route53 hosted zone"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
''',
        "outputs.tf": '''output "hosted_zone_id" {
  description = "Hosted zone ID"
  value       = var.domain_name != "" ? aws_route53_zone.main[0].zone_id : null
}

output "name_servers" {
  description = "Name servers"
  value       = var.domain_name != "" ? aws_route53_zone.main[0].name_servers : null
}
''',
        "versions.tf": '''terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
'''
    },
    
    "monitoring": {
        "main.tf": '''################################################################################
# Monitoring Layer - CloudWatch, SNS
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
    tags = merge(var.common_tags, { Layer = "monitoring" })
  }
}

################################################################################
# SNS Topics for Alerts
################################################################################

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"

  tags = var.common_tags
}

resource "aws_sns_topic_subscription" "alerts_email" {
  count = var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/application/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = var.common_tags
}
''',
        "variables.tf": '''variable "environment" {
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

variable "alert_email" {
  description = "Email for alerts"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 30
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
''',
        "outputs.tf": '''output "sns_topic_arn" {
  description = "SNS topic ARN"
  value       = aws_sns_topic.alerts.arn
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.application.name
}
''',
        "versions.tf": '''terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
'''
    }
}

# Generate all layer files
print("🚀 Generating layer configurations...")
for layer_name, files in LAYERS_CONFIG.items():
    layer_dir = f"{BASE_DIR}/layers/{layer_name}"
    Path(layer_dir).mkdir(parents=True, exist_ok=True)
    
    for filename, content in files.items():
        filepath = f"{layer_dir}/{filename}"
        with open(filepath, "w") as f:
            f.write(content)
    
    print(f"  ✅ Created layer: {layer_name}")

print("\n✅ All layers generated successfully!")
