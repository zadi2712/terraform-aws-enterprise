################################################################################
# Basic VPC Endpoints Example
# Description: Minimal configuration for common interface endpoints
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
# VPC Endpoints Module - Basic Configuration
################################################################################

module "vpc_endpoints" {
  source = "../../"

  # VPC Configuration
  vpc_id             = "vpc-abc123"
  vpc_cidr           = "10.0.0.0/16"
  private_subnet_ids = ["subnet-123", "subnet-456"]
  name_prefix        = "example-basic"

  # Create security group automatically
  create_security_group = true

  # Basic endpoints for common services
  endpoints = {
    # EC2 API access
    ec2 = {
      service             = "ec2"
      private_dns_enabled = true
    }
    
    # CloudWatch Logs
    logs = {
      service             = "logs"
      private_dns_enabled = true
    }
    
    # Systems Manager
    ssm = {
      service             = "ssm"
      private_dns_enabled = true
    }
    
    # Secrets Manager
    secretsmanager = {
      service             = "secretsmanager"
      private_dns_enabled = true
    }
  }

  tags = {
    Environment = "development"
    Example     = "basic"
  }
}

################################################################################
# Outputs
################################################################################

output "security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = module.vpc_endpoints.security_group_id
}

output "interface_endpoints" {
  description = "Interface endpoint IDs"
  value       = module.vpc_endpoints.interface_endpoints
}

output "endpoint_count" {
  description = "Number of endpoints created"
  value       = module.vpc_endpoints.endpoint_count
}
