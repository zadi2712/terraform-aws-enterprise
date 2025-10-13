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


################################################################################
# Store Outputs in SSM Parameter Store
################################################################################

module "ssm_outputs" {
  source = "../../../modules/ssm-outputs"

  project_name = var.project_name
  environment  = var.environment
  layer_name   = "storage"

  outputs = {
    application_bucket_id   = module.application_bucket.bucket_id
    application_bucket_arn  = module.application_bucket.bucket_arn
    application_bucket_name = module.application_bucket.bucket_id
    logs_bucket_id          = module.logs_bucket.bucket_id
    logs_bucket_arn         = module.logs_bucket.bucket_arn
    logs_bucket_name        = module.logs_bucket.bucket_id
  }

  output_descriptions = {
    application_bucket_id   = "Application S3 bucket ID"
    application_bucket_arn  = "Application S3 bucket ARN"
    application_bucket_name = "Application S3 bucket name"
    logs_bucket_id          = "Logs S3 bucket ID"
    logs_bucket_arn         = "Logs S3 bucket ARN"
    logs_bucket_name        = "Logs S3 bucket name"
  }

  tags = var.common_tags

  depends_on = [
    module.application_bucket,
    module.logs_bucket
  ]
}
