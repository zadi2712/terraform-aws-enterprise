#!/usr/bin/env python3
"""
Generate complete Terraform enterprise infrastructure
Creates all remaining modules and layer configurations
"""

import os
from pathlib import Path

BASE_DIR = "/Users/diego/terraform-aws-enterprise"

# Module Templates
MODULES = {
    "rds": {
        "main.tf": '''################################################################################
# RDS Module - PostgreSQL/MySQL Database
################################################################################

resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.kms_key_id

  db_name  = var.database_name
  username = var.master_username
  password = var.master_password
  port     = var.port

  multi_az               = var.multi_az
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = var.vpc_security_group_ids

  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  monitoring_interval             = var.monitoring_interval
  monitoring_role_arn             = var.monitoring_role_arn

  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_kms_key_id

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final-snapshot"

  tags = merge(var.tags, { Name = var.identifier })
}

resource "aws_db_parameter_group" "this" {
  count = var.create_parameter_group ? 1 : 0

  name   = "${var.identifier}-params"
  family = var.parameter_group_family

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = var.tags
}
''',
        "variables.tf": '''variable "identifier" {
  description = "Database identifier"
  type        = string
}

variable "engine" {
  description = "Database engine (postgres, mysql)"
  type        = string
}

variable "engine_version" {
  description = "Engine version"
  type        = string
}

variable "instance_class" {
  description = "Instance class"
  type        = string
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
}

variable "max_allocated_storage" {
  description = "Maximum allocated storage for autoscaling"
  type        = number
  default     = null
}

variable "storage_type" {
  description = "Storage type"
  type        = string
  default     = "gp3"
}

variable "storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "database_name" {
  description = "Database name"
  type        = string
}

variable "master_username" {
  description = "Master username"
  type        = string
}

variable "master_password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

variable "port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "multi_az" {
  description = "Enable Multi-AZ"
  type        = bool
  default     = false
}

variable "db_subnet_group_name" {
  description = "DB subnet group name"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "VPC security group IDs"
  type        = list(string)
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "enabled_cloudwatch_logs_exports" {
  description = "CloudWatch log exports"
  type        = list(string)
  default     = []
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval"
  type        = number
  default     = 0
}

variable "monitoring_role_arn" {
  description = "IAM role for enhanced monitoring"
  type        = string
  default     = null
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = false
}

variable "performance_insights_kms_key_id" {
  description = "KMS key for Performance Insights"
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = false
}

variable "create_parameter_group" {
  description = "Create parameter group"
  type        = bool
  default     = false
}

variable "parameter_group_family" {
  description = "Parameter group family"
  type        = string
  default     = ""
}

variable "parameters" {
  description = "Database parameters"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
''',
        "outputs.tf": '''output "db_instance_id" {
  description = "Database instance ID"
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "Database instance ARN"
  value       = aws_db_instance.this.arn
}

output "db_instance_endpoint" {
  description = "Database endpoint"
  value       = aws_db_instance.this.endpoint
}

output "db_instance_address" {
  description = "Database address"
  value       = aws_db_instance.this.address
}

output "db_instance_port" {
  description = "Database port"
  value       = aws_db_instance.this.port
}
'''
    },
    
    "s3": {
        "main.tf": '''################################################################################
# S3 Module - Object Storage with Security
################################################################################

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name

  tags = merge(var.tags, { Name = var.bucket_name })
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = var.kms_key_id != null
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = var.block_public_access
  block_public_policy     = var.block_public_access
  ignore_public_acls      = var.block_public_access
  restrict_public_buckets = var.block_public_access
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = length(var.lifecycle_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      dynamic "transition" {
        for_each = lookup(rule.value, "transitions", [])
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "expiration" {
        for_each = lookup(rule.value, "expiration", null) != null ? [rule.value.expiration] : []
        content {
          days = expiration.value.days
        }
      }
    }
  }
}
''',
        "variables.tf": '''variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "versioning_enabled" {
  description = "Enable versioning"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "block_public_access" {
  description = "Block public access"
  type        = bool
  default     = true
}

variable "lifecycle_rules" {
  description = "Lifecycle rules"
  type        = list(any)
  default     = []
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
''',
        "outputs.tf": '''output "bucket_id" {
  description = "Bucket ID"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "Bucket ARN"
  value       = aws_s3_bucket.this.arn
}
'''
    },
    
    "ecs": {
        "main.tf": '''################################################################################
# ECS Module - Container Orchestration
################################################################################

resource "aws_ecs_cluster" "this" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = var.container_insights_enabled ? "enabled" : "disabled"
  }

  tags = merge(var.tags, { Name = var.cluster_name })
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = var.capacity_providers

  dynamic "default_capacity_provider_strategy" {
    for_each = var.default_capacity_provider_strategy
    content {
      capacity_provider = default_capacity_provider_strategy.value.capacity_provider
      weight            = default_capacity_provider_strategy.value.weight
      base              = lookup(default_capacity_provider_strategy.value, "base", null)
    }
  }
}
''',
        "variables.tf": '''variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "container_insights_enabled" {
  description = "Enable Container Insights"
  type        = bool
  default     = true
}

variable "capacity_providers" {
  description = "Capacity providers"
  type        = list(string)
  default     = ["FARGATE", "FARGATE_SPOT"]
}

variable "default_capacity_provider_strategy" {
  description = "Default capacity provider strategy"
  type        = list(any)
  default     = []
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
''',
        "outputs.tf": '''output "cluster_id" {
  description = "Cluster ID"
  value       = aws_ecs_cluster.this.id
}

output "cluster_arn" {
  description = "Cluster ARN"
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "Cluster name"
  value       = aws_ecs_cluster.this.name
}
'''
    }
}

# Generate all modules
print("🚀 Generating Terraform modules...")
for module_name, files in MODULES.items():
    module_dir = f"{BASE_DIR}/modules/{module_name}"
    Path(module_dir).mkdir(parents=True, exist_ok=True)
    
    for filename, content in files.items():
        filepath = f"{module_dir}/{filename}"
        with open(filepath, "w") as f:
            f.write(content)
    
    print(f"  ✅ Created module: {module_name}")

print("\n✅ All modules generated successfully!")
