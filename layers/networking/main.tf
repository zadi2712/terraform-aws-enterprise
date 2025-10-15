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
  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
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
      subnet_ids          = module.vpc.private_subnet_ids
    }
    kms = {
      service             = "kms"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnet_ids
    }
    rds = {
      service             = "rds"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnet_ids
    }
    elasticache = {
      service             = "elasticache"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnet_ids
    }
    sns = {
      service             = "sns"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnet_ids
    }
    sqs = {
      service             = "sqs"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnet_ids
    }
    lambda = {
      service             = "lambda"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnet_ids
    }
    sts = {
      service             = "sts"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnet_ids
    }
    elasticloadbalancing = {
      service             = "elasticloadbalancing"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnet_ids
    }
    autoscaling = {
      service             = "autoscaling"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnet_ids
    }
    cloudwatch = {
      service             = "monitoring"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnet_ids
    }
    events = {
      service             = "events"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnet_ids
    }
    # Gateway Endpoints (no subnets required)
    s3 = {
      service      = "s3"
      service_type = "Gateway"
      route_table_ids = concat(
        module.vpc.private_route_table_ids,
        module.vpc.public_route_table_ids
      )
    }
    dynamodb = {
      service      = "dynamodb"
      service_type = "Gateway"
      route_table_ids = concat(
        module.vpc.private_route_table_ids,
        module.vpc.public_route_table_ids
      )
    }
  }

  # VPC and network configuration
  vpc_cidr              = module.vpc.vpc_cidr
  name_prefix           = "${var.project_name}-${var.environment}"
  create_security_group = true

  # Tags
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-vpc-endpoints"
      Environment = var.environment
    }
  )

  depends_on = [module.vpc]
}


################################################################################
# Store Outputs in SSM Parameter Store
# Enables both terraform_remote_state and SSM-based retrieval
################################################################################

module "ssm_outputs" {
  source = "../../../modules/ssm-outputs"

  project_name = var.project_name
  environment  = var.environment
  layer_name   = "networking"

  outputs = {
    # VPC
    vpc_id   = module.vpc.vpc_id
    vpc_cidr = module.vpc.vpc_cidr
    vpc_arn  = module.vpc.vpc_arn

    # Subnets
    public_subnet_ids          = module.vpc.public_subnet_ids
    private_subnet_ids         = module.vpc.private_subnet_ids
    database_subnet_ids        = module.vpc.database_subnet_ids
    database_subnet_group_name = module.vpc.database_subnet_group_name

    # Gateways
    nat_gateway_ids     = module.vpc.nat_gateway_ids
    internet_gateway_id = module.vpc.internet_gateway_id

    # Route Tables
    public_route_table_ids  = module.vpc.public_route_table_ids
    private_route_table_ids = module.vpc.private_route_table_ids

    # VPC Endpoints
    vpc_endpoint_s3_id              = module.vpc.vpc_endpoint_s3_id
    vpc_endpoint_dynamodb_id        = module.vpc.vpc_endpoint_dynamodb_id
    vpc_endpoints_security_group_id = var.enable_vpc_endpoints ? module.vpc_endpoints[0].security_group_id : null
    vpc_endpoints_interface         = var.enable_vpc_endpoints ? module.vpc_endpoints[0].interface_endpoints : {}
    vpc_endpoints_gateway           = var.enable_vpc_endpoints ? module.vpc_endpoints[0].gateway_endpoints : {}
    vpc_endpoints_all               = var.enable_vpc_endpoints ? module.vpc_endpoints[0].all_endpoints : {}
    vpc_endpoints_count             = var.enable_vpc_endpoints ? module.vpc_endpoints[0].endpoint_count : { interface = 0, gateway = 0, total = 0 }

    # Flow Logs
    vpc_flow_log_id                        = module.vpc.vpc_flow_log_id
    vpc_flow_log_cloudwatch_log_group_name = module.vpc.vpc_flow_log_cloudwatch_log_group_name

    # Other
    availability_zones = var.availability_zones

    # Network Summary
    network_summary = {
      vpc_id              = module.vpc.vpc_id
      vpc_cidr            = module.vpc.vpc_cidr
      public_subnet_ids   = module.vpc.public_subnet_ids
      private_subnet_ids  = module.vpc.private_subnet_ids
      database_subnet_ids = module.vpc.database_subnet_ids
      availability_zones  = var.availability_zones
      environment         = var.environment
    }
  }

  output_descriptions = {
    vpc_id                                 = "ID of the VPC"
    vpc_cidr                               = "CIDR block of the VPC"
    vpc_arn                                = "ARN of the VPC"
    public_subnet_ids                      = "List of public subnet IDs"
    private_subnet_ids                     = "List of private subnet IDs"
    database_subnet_ids                    = "List of database subnet IDs"
    database_subnet_group_name             = "Name of the database subnet group"
    nat_gateway_ids                        = "List of NAT Gateway IDs"
    internet_gateway_id                    = "ID of the Internet Gateway"
    public_route_table_ids                 = "List of public route table IDs"
    private_route_table_ids                = "List of private route table IDs"
    vpc_endpoint_s3_id                     = "ID of the S3 VPC endpoint"
    vpc_endpoint_dynamodb_id               = "ID of the DynamoDB VPC endpoint"
    vpc_endpoints_security_group_id        = "ID of the VPC endpoints security group"
    vpc_endpoints_interface                = "Map of interface VPC endpoint IDs"
    vpc_endpoints_gateway                  = "Map of gateway VPC endpoint IDs"
    vpc_endpoints_all                      = "Map of all VPC endpoint IDs"
    vpc_endpoints_count                    = "Count of VPC endpoints created"
    vpc_flow_log_id                        = "ID of the VPC Flow Log"
    vpc_flow_log_cloudwatch_log_group_name = "Name of the CloudWatch Log Group for VPC Flow Logs"
    availability_zones                     = "List of availability zones used"
    network_summary                        = "Summary of network configuration for use by other layers"
  }

  tags = var.common_tags

  depends_on = [module.vpc, module.vpc_endpoints]
}
