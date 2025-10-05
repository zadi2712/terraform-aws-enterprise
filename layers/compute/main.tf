################################################################################
# Compute Layer - EC2, ECS, Lambda
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
