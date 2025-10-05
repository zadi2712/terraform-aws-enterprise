################################################################################
# Storage Layer - S3, EFS
################################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
