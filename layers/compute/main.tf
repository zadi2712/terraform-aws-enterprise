################################################################################
# Compute Layer - EC2, ECS, EKS, Lambda
# Description: Compute resources including container orchestration and serverless
# Version: 2.0 - Added EKS cluster support
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

# Data sources
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
# EKS Cluster
################################################################################

module "eks_cluster" {
  source = "../../../modules/eks"
  count  = var.enable_eks ? 1 : 0

  cluster_name    = "${var.project_name}-${var.environment}-eks"
  cluster_version = var.eks_cluster_version
  
  vpc_id     = data.terraform_remote_state.networking.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.networking.outputs.private_subnet_ids
  
  # Network configuration
  endpoint_private_access = var.eks_endpoint_private_access
  endpoint_public_access  = var.eks_endpoint_public_access
  public_access_cidrs     = var.eks_public_access_cidrs
  
  # Modern features
  enable_pod_identity                         = var.eks_enable_pod_identity
  authentication_mode                         = var.eks_authentication_mode
  bootstrap_cluster_creator_admin_permissions = true
  
  # Encryption
  kms_key_arn = try(data.terraform_remote_state.security.outputs.kms_key_arn, null)
  
  # Logging
  cluster_log_types   = var.eks_cluster_log_types
  log_retention_days  = var.eks_log_retention_days
  
  # Node groups
  node_groups = var.eks_node_groups
  
  # Fargate profiles
  fargate_profiles = var.eks_fargate_profiles
  
  # Autoscaling
  enable_karpenter          = var.eks_enable_karpenter
  enable_cluster_autoscaler = var.eks_enable_cluster_autoscaler
  
  # Storage drivers
  enable_ebs_csi_driver = var.eks_enable_ebs_csi_driver
  enable_efs_csi_driver = var.eks_enable_efs_csi_driver
  
  # Monitoring
  enable_cloudwatch_observability = var.eks_enable_cloudwatch_observability
  enable_guardduty_agent          = var.eks_enable_guardduty_agent
  
  # Controllers
  enable_aws_load_balancer_controller = var.eks_enable_aws_load_balancer_controller
  enable_external_dns                 = var.eks_enable_external_dns
  external_dns_route53_zone_arns      = var.eks_external_dns_route53_zone_arns
  
  # Access entries
  access_entries = var.eks_access_entries
  
  tags = var.common_tags
}

################################################################################
# ECS Cluster
################################################################################

module "ecs_cluster" {
  source = "../../../modules/ecs"
  count  = var.enable_ecs ? 1 : 0

  cluster_name               = "${var.project_name}-${var.environment}-ecs"
  container_insights_enabled = var.enable_container_insights

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
# Application Load Balancer for ECS/EKS
################################################################################

module "alb_security_group" {
  source = "../../../modules/security-group"
  count  = var.enable_alb ? 1 : 0

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

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]

  tags = var.common_tags
}

module "alb" {
  source = "../../../modules/alb"
  count  = var.enable_alb ? 1 : 0

  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  
  vpc_id          = data.terraform_remote_state.networking.outputs.vpc_id
  subnet_ids      = data.terraform_remote_state.networking.outputs.public_subnet_ids
  security_groups = [module.alb_security_group[0].security_group_id]
  
  enable_deletion_protection = var.environment == "prod" ? true : false
  enable_http2              = true
  enable_waf                = var.environment == "prod" ? true : false
  
  access_logs_enabled = true
  access_logs_bucket  = try(data.terraform_remote_state.storage.outputs.logs_bucket_name, null)
  access_logs_prefix  = "alb"
  
  tags = var.common_tags
}

################################################################################
# EC2 Bastion Host (Optional)
################################################################################

module "bastion" {
  source = "../../../modules/ec2"
  count  = var.enable_bastion ? 1 : 0

  name          = "${var.project_name}-${var.environment}-bastion"
  instance_type = var.bastion_instance_type
  ami_id        = var.bastion_ami_id
  
  subnet_id              = data.terraform_remote_state.networking.outputs.public_subnet_ids[0]
  vpc_security_group_ids = [module.bastion_security_group[0].security_group_id]
  
  key_name                    = var.bastion_key_name
  associate_public_ip_address = true
  
  enable_monitoring = true
  
  user_data = var.bastion_user_data
  
  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-bastion"
      Role = "bastion"
    }
  )
}

module "bastion_security_group" {
  source = "../../../modules/security-group"
  count  = var.enable_bastion ? 1 : 0

  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.bastion_allowed_cidrs
      description = "Allow SSH from allowed CIDRs"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]

  tags = var.common_tags
}
