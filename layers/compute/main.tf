################################################################################
# Compute Layer - Main Configuration
# Description: EC2, ECS, EKS, Lambda, ALB
# Dependencies: networking, security
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
        Layer     = "compute"
        Terraform = "true"
      }
    )
  }
}

# Data sources for networking layer outputs
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
# Application Load Balancer
################################################################################

module "alb" {
  source = "../../../modules/alb"
  count  = var.enable_alb ? 1 : 0

  environment = var.environment
  name        = "${var.project_name}-${var.environment}-alb"

  vpc_id          = data.terraform_remote_state.networking.outputs.vpc_id
  subnets         = data.terraform_remote_state.networking.outputs.public_subnet_ids
  security_groups = [module.alb_security_group[0].id]

  enable_deletion_protection = var.environment == "prod" ? true : false
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  tags = var.common_tags
}

module "alb_security_group" {
  source = "../../../modules/security-group"
  count  = var.enable_alb ? 1 : 0

  environment = var.environment
  name        = "${var.project_name}-${var.environment}-alb-sg"

  vpc_id = data.terraform_remote_state.networking.outputs.vpc_id

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP from Internet"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS from Internet"
    }
  ]

  tags = var.common_tags
}

################################################################################
# ECS Cluster
################################################################################

module "ecs_cluster" {
  source = "../../../modules/ecs"
  count  = var.enable_ecs ? 1 : 0

  environment = var.environment
  name        = "${var.project_name}-${var.environment}-ecs"

  enable_container_insights = true
  
  tags = var.common_tags
}

################################################################################
# EKS Cluster
################################################################################

module "eks_cluster" {
  source = "../../../modules/eks"
  count  = var.enable_eks ? 1 : 0

  environment = var.environment
  name        = "${var.project_name}-${var.environment}-eks"

  vpc_id     = data.terraform_remote_state.networking.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.networking.outputs.private_subnet_ids

  cluster_version = var.eks_cluster_version

  enable_irsa                     = true
  enable_cluster_autoscaler       = true
  enable_metrics_server           = true

  tags = var.common_tags
}

################################################################################
# Lambda Functions
################################################################################

module "lambda_functions" {
  source   = "../../../modules/lambda"
  for_each = var.lambda_functions

  environment = var.environment
  name        = "${var.project_name}-${var.environment}-${each.key}"

  runtime     = each.value.runtime
  handler     = each.value.handler
  memory_size = each.value.memory_size
  timeout     = each.value.timeout

  vpc_subnet_ids         = data.terraform_remote_state.networking.outputs.private_subnet_ids
  vpc_security_group_ids = [module.lambda_security_group.id]

  environment_variables = each.value.environment_variables

  tags = var.common_tags
}

module "lambda_security_group" {
  source = "../../../modules/security-group"

  environment = var.environment
  name        = "${var.project_name}-${var.environment}-lambda-sg"

  vpc_id = data.terraform_remote_state.networking.outputs.vpc_id

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound"
    }
  ]

  tags = var.common_tags
}
