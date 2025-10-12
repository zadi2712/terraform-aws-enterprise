################################################################################
# Complete VPC Endpoints Example
# Description: Full enterprise setup with interface and gateway endpoints
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
# Data Sources
################################################################################

data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  
  tags = {
    Type = "private"
  }
}

data "aws_route_tables" "private" {
  vpc_id = var.vpc_id
  
  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}

################################################################################
# VPC Endpoints Module - Complete Configuration
################################################################################

module "vpc_endpoints" {
  source = "../../"

  # VPC Configuration
  vpc_id             = var.vpc_id
  vpc_cidr           = data.aws_vpc.main.cidr_block
  private_subnet_ids = data.aws_subnets.private.ids
  route_table_ids    = data.aws_route_tables.private.ids
  name_prefix        = "enterprise-prod"

  # Security Group
  create_security_group = true

  # Comprehensive Endpoint Configuration
  endpoints = {
    ############################################################################
    # Compute Services
    ############################################################################
    ec2 = {
      service             = "ec2"
      private_dns_enabled = true
    }
    
    ec2messages = {
      service             = "ec2messages"
      private_dns_enabled = true
    }
    
    autoscaling = {
      service             = "autoscaling"
      private_dns_enabled = true
    }
    
    lambda = {
      service             = "lambda"
      private_dns_enabled = true
    }
    
    ############################################################################
    # Container Services
    ############################################################################
    ecs = {
      service             = "ecs"
      private_dns_enabled = true
    }
    
    ecs_agent = {
      service             = "ecs-agent"
      private_dns_enabled = true
    }
    
    ecs_telemetry = {
      service             = "ecs-telemetry"
      private_dns_enabled = true
    }
    
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
    }
    
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
    }
    
    ############################################################################
    # Database Services
    ############################################################################
    rds = {
      service             = "rds"
      private_dns_enabled = true
    }
    
    rds_data = {
      service             = "rds-data"
      private_dns_enabled = true
    }
    
    elasticache = {
      service             = "elasticache"
      private_dns_enabled = true
    }
    
    ############################################################################
    # Security & Identity
    ############################################################################
    kms = {
      service             = "kms"
      private_dns_enabled = true
    }
    
    secretsmanager = {
      service             = "secretsmanager"
      private_dns_enabled = true
    }
    
    sts = {
      service             = "sts"
      private_dns_enabled = true
    }
    
    ############################################################################
    # Monitoring & Logging
    ############################################################################
    logs = {
      service             = "logs"
      private_dns_enabled = true
    }
    
    monitoring = {
      service             = "monitoring"
      private_dns_enabled = true
    }
    
    events = {
      service             = "events"
      private_dns_enabled = true
    }
    
    ############################################################################
    # Messaging Services
    ############################################################################
    sns = {
      service             = "sns"
      private_dns_enabled = true
    }
    
    sqs = {
      service             = "sqs"
      private_dns_enabled = true
    }
    
    ############################################################################
    # Systems Management
    ############################################################################
    ssm = {
      service             = "ssm"
      private_dns_enabled = true
    }
    
    ssmmessages = {
      service             = "ssmmessages"
      private_dns_enabled = true
    }
    
    ############################################################################
    # Load Balancing
    ############################################################################
    elasticloadbalancing = {
      service             = "elasticloadbalancing"
      private_dns_enabled = true
    }
    
    ############################################################################
    # Gateway Endpoints (FREE)
    ############################################################################
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = data.aws_route_tables.private.ids
    }
    
    dynamodb = {
      service         = "dynamodb"
      service_type    = "Gateway"
      route_table_ids = data.aws_route_tables.private.ids
    }
  }

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
    Project     = "enterprise-infrastructure"
    CostCenter  = "platform"
  }
}

################################################################################
# Variables
################################################################################

variable "vpc_id" {
  description = "VPC ID where endpoints will be created"
  type        = string
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

output "gateway_endpoints" {
  description = "Gateway endpoint IDs"
  value       = module.vpc_endpoints.gateway_endpoints
}

output "all_endpoints" {
  description = "All endpoint IDs"
  value       = module.vpc_endpoints.all_endpoints
}

output "endpoint_count" {
  description = "Endpoint count breakdown"
  value       = module.vpc_endpoints.endpoint_count
}

output "dns_entries" {
  description = "DNS entries for interface endpoints"
  value       = module.vpc_endpoints.interface_endpoint_dns_entries
}
