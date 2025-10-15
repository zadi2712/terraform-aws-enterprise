################################################################################
# Advanced VPC Endpoints Example
# Description: Custom policies, security groups, and advanced configurations
################################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

################################################################################
# Custom Security Group
################################################################################

resource "aws_security_group" "custom_vpce" {
  name_prefix = "custom-vpce-"
  description = "Custom security group for VPC endpoints with restricted access"
  vpc_id      = var.vpc_id

  # Only allow HTTPS from specific CIDR
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
    description = "HTTPS from allowed CIDR only"
  }

  # No egress rules (deny all outbound)

  tags = {
    Name = "custom-vpce-sg"
  }
}

################################################################################
# Endpoint Policies
################################################################################

# Restrictive S3 policy - only specific buckets
data "aws_iam_policy_document" "s3_endpoint_policy" {
  statement {
    sid    = "AllowSpecificBuckets"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::${var.app_bucket}",
      "arn:aws:s3:::${var.app_bucket}/*",
      "arn:aws:s3:::${var.logs_bucket}",
      "arn:aws:s3:::${var.logs_bucket}/*"
    ]
  }

  statement {
    sid    = "DenyUnencryptedObjectUploads"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:PutObject"]

    resources = [
      "arn:aws:s3:::${var.app_bucket}/*",
      "arn:aws:s3:::${var.logs_bucket}/*"
    ]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["AES256", "aws:kms"]
    }
  }
}

# Restrictive Secrets Manager policy
data "aws_iam_policy_document" "secrets_endpoint_policy" {
  statement {
    sid    = "AllowSpecificSecrets"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.environment}/*"
    ]
  }
}

################################################################################
# VPC Endpoints Module - Advanced Configuration
################################################################################

module "vpc_endpoints" {
  source = "../../"

  # VPC Configuration
  vpc_id             = var.vpc_id
  vpc_cidr           = var.vpc_cidr
  private_subnet_ids = var.private_subnet_ids
  route_table_ids    = var.route_table_ids
  name_prefix        = "advanced-${var.environment}"

  # Use custom security group
  create_security_group = false
  security_group_ids    = [aws_security_group.custom_vpce.id]

  endpoints = {
    # S3 with custom policy and specific subnet
    s3_interface = {
      service             = "s3"
      service_type        = "Interface"
      private_dns_enabled = false                       # Using custom DNS
      subnet_ids          = [var.private_subnet_ids[0]] # Single AZ for cost
      policy              = data.aws_iam_policy_document.s3_endpoint_policy.json
      tags = {
        Purpose = "Restricted S3 access"
      }
    }

    # Secrets Manager with restrictive policy
    secretsmanager = {
      service             = "secretsmanager"
      private_dns_enabled = true
      policy              = data.aws_iam_policy_document.secrets_endpoint_policy.json
      tags = {
        Purpose    = "Application secrets"
        Compliance = "PCI-DSS"
      }
    }

    # KMS with specific subnet configuration
    kms = {
      service             = "kms"
      private_dns_enabled = true
      subnet_ids          = var.private_subnet_ids
      tags = {
        Purpose    = "Encryption operations"
        Compliance = "HIPAA"
      }
    }

    # ECR with high availability
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
      subnet_ids          = var.private_subnet_ids # All AZs
    }

    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      subnet_ids          = var.private_subnet_ids # All AZs
    }

    # Gateway endpoint with policy
    s3_gateway = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = var.route_table_ids
      policy          = data.aws_iam_policy_document.s3_endpoint_policy.json
    }

    # DynamoDB gateway endpoint
    dynamodb = {
      service         = "dynamodb"
      service_type    = "Gateway"
      route_table_ids = var.route_table_ids
    }
  }

  tags = {
    Environment        = var.environment
    ManagedBy          = "Terraform"
    SecurityPosture    = "High"
    DataClassification = "Confidential"
  }
}

################################################################################
# Variables
################################################################################

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "route_table_ids" {
  description = "Route table IDs"
  type        = list(string)
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "allowed_cidr" {
  description = "CIDR block allowed to access endpoints"
  type        = string
}

variable "app_bucket" {
  description = "Application S3 bucket name"
  type        = string
}

variable "logs_bucket" {
  description = "Logs S3 bucket name"
  type        = string
}

################################################################################
# Outputs
################################################################################

output "custom_security_group_id" {
  description = "Custom security group ID"
  value       = aws_security_group.custom_vpce.id
}

output "s3_interface_endpoint" {
  description = "S3 interface endpoint details"
  value = {
    id          = module.vpc_endpoints.interface_endpoints["s3_interface"]
    arn         = module.vpc_endpoints.interface_endpoint_arns["s3_interface"]
    dns_entries = module.vpc_endpoints.interface_endpoint_dns_entries["s3_interface"]
  }
}

output "s3_gateway_endpoint" {
  description = "S3 gateway endpoint ID"
  value       = module.vpc_endpoints.gateway_endpoints["s3_gateway"]
}

output "endpoint_policies" {
  description = "Endpoint policies applied"
  value = {
    s3_policy      = data.aws_iam_policy_document.s3_endpoint_policy.json
    secrets_policy = data.aws_iam_policy_document.secrets_endpoint_policy.json
  }
  sensitive = true
}

output "all_endpoints" {
  description = "All endpoint IDs"
  value       = module.vpc_endpoints.all_endpoints
}
