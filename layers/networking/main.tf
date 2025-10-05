################################################################################
# Networking Layer - Main Configuration
# Description: VPC, Subnets, NAT Gateways, Internet Gateway, Route Tables
# Well-Architected Pillar: Reliability, Security
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
    # Backend configuration provided via backend.conf file
    # terraform init -backend-config=environments/<env>/backend.conf
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      var.common_tags,
      {
        Layer     = "networking"
        Terraform = "true"
      }
    )
  }
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "../../../modules/vpc"

  # VPC Configuration
  vpc_name = "${var.project_name}-${var.environment}-vpc"
  vpc_cidr = var.vpc_cidr

  # Availability Zones
  availability_zones = var.availability_zones

  # Subnet Configuration
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs

  # NAT Gateway Configuration
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  one_nat_gateway_per_az = var.one_nat_gateway_per_az

  # VPC Features
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs
  enable_flow_logs                      = var.enable_flow_logs
  flow_logs_retention_in_days           = var.flow_logs_retention_days
  create_flow_logs_cloudwatch_log_group = true
  create_flow_logs_cloudwatch_iam_role  = true

  # VPC Endpoints
  enable_s3_endpoint       = var.enable_vpc_endpoints
  enable_dynamodb_endpoint = var.enable_vpc_endpoints

  # Tags
  environment = var.environment
  tags        = var.common_tags
}

################################################################################
# VPC Endpoints for AWS Services (PrivateLink)
################################################################################

module "vpc_endpoints" {
  source = "../../../modules/vpc-endpoints"
  count  = var.enable_vpc_endpoints ? 1 : 0

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  endpoints = {
    ec2 = {
      service             = "ec2"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnet_ids
    }
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnet_ids
    }
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnet_ids
    }
    ecs = {
      service             = "ecs"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnet_ids
    }
    ecs_telemetry = {
      service             = "ecs-telemetry"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnet_ids
    }
    ssm = {
      service             = "ssm"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnet_ids
    }
    logs = {
      service             = "logs"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnet_ids
    }
    secretsmanager = {
      service             = "secretsmanager"
      private_dns_enabled = true
