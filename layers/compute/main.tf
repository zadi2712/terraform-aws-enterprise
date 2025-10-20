################################################################################
# Compute Layer - EC2, ECS, EKS, Lambda
# Description: Compute resources including container orchestration and serverless
# Version: 2.0 - Added EKS cluster support
################################################################################

terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
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

data "terraform_remote_state" "storage" {
  backend = "s3"
  config = {
    bucket = "terraform-state-${var.environment}-${data.aws_caller_identity.current.account_id}"
    key    = "layers/storage/${var.environment}/terraform.tfstate"
    region = var.aws_region
  }
}

data "aws_caller_identity" "current" {}

################################################################################
# ECR Repositories
################################################################################

# Application repositories
module "ecr_repositories" {
  source = "../../../modules/ecr"
  
  for_each = var.ecr_repositories

  repository_name      = "${var.project_name}-${var.environment}-${each.key}"
  image_tag_mutability = each.value.image_tag_mutability
  
  # Encryption
  encryption_type = var.ecr_encryption_type
  kms_key_arn     = var.ecr_encryption_type == "KMS" ? try(data.terraform_remote_state.security.outputs.kms_key_arn, null) : null
  
  # Scanning
  scan_on_push             = each.value.scan_on_push
  enable_enhanced_scanning = each.value.enable_enhanced_scanning
  scan_frequency           = each.value.scan_frequency
  
  # Lifecycle
  max_image_count  = each.value.max_image_count
  lifecycle_policy = each.value.lifecycle_policy
  
  # Access
  enable_cross_account_access = each.value.enable_cross_account_access
  allowed_account_ids         = each.value.allowed_account_ids
  enable_lambda_pull          = each.value.enable_lambda_pull
  
  # Replication
  enable_replication       = each.value.enable_replication
  replication_destinations = each.value.replication_destinations
  
  # Pull through cache
  enable_pull_through_cache         = each.value.enable_pull_through_cache
  pull_through_cache_prefix         = each.value.pull_through_cache_prefix
  upstream_registry_url             = each.value.upstream_registry_url
  pull_through_cache_credential_arn = each.value.pull_through_cache_credential_arn
  
  # Monitoring
  enable_scan_findings_logging = var.ecr_enable_scan_findings_logging
  log_retention_days           = var.ecr_log_retention_days
  
  tags = merge(
    var.common_tags,
    {
      Application = each.key
    }
  )
}

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

  # Network configuration
  vpc_id                = data.terraform_remote_state.networking.outputs.vpc_id
  create_security_group = var.ecs_create_security_group
  alb_security_group_id = var.enable_alb && var.ecs_create_security_group ? module.alb_security_group[0].security_group_id : null
  task_container_port   = var.ecs_task_container_port

  # Capacity providers
  capacity_providers = var.ecs_capacity_providers

  default_capacity_provider_strategy = var.ecs_default_capacity_provider_strategy

  # IAM roles
  create_task_execution_role = var.ecs_create_task_execution_role
  create_task_role           = var.ecs_create_task_role

  # Service discovery
  enable_service_discovery    = var.ecs_enable_service_discovery
  service_discovery_namespace = var.ecs_service_discovery_namespace

  # Logging and debugging
  enable_execute_command = var.ecs_enable_execute_command
  log_retention_days     = var.ecs_log_retention_days
  kms_key_arn            = try(data.terraform_remote_state.security.outputs.kms_key_arn, null)

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


################################################################################
# Store Outputs in SSM Parameter Store
################################################################################

module "ssm_outputs" {
  source = "../../../modules/ssm-outputs"

  project_name = var.project_name
  environment  = var.environment
  layer_name   = "compute"

  outputs = {
    # ECR
    ecr_repository_urls  = { for k, v in module.ecr_repositories : k => v.repository_url }
    ecr_repository_arns  = { for k, v in module.ecr_repositories : k => v.repository_arn }
    ecr_repository_names = { for k, v in module.ecr_repositories : k => v.repository_name }

    # EKS
    eks_cluster_id                             = var.enable_eks ? module.eks_cluster[0].cluster_id : null
    eks_cluster_name                           = var.enable_eks ? module.eks_cluster[0].cluster_name : null
    eks_cluster_endpoint                       = var.enable_eks ? module.eks_cluster[0].cluster_endpoint : null
    eks_cluster_version                        = var.enable_eks ? module.eks_cluster[0].cluster_version : null
    eks_cluster_security_group_id              = var.enable_eks ? module.eks_cluster[0].cluster_security_group_id : null
    eks_oidc_provider_arn                      = var.enable_eks ? module.eks_cluster[0].oidc_provider_arn : null
    eks_karpenter_iam_role_arn                 = var.enable_eks ? module.eks_cluster[0].karpenter_iam_role_arn : null
    eks_karpenter_instance_profile_name        = var.enable_eks ? module.eks_cluster[0].karpenter_instance_profile_name : null
    eks_aws_load_balancer_controller_iam_role_arn = var.enable_eks ? module.eks_cluster[0].aws_load_balancer_controller_iam_role_arn : null
    eks_external_dns_iam_role_arn              = var.enable_eks ? module.eks_cluster[0].external_dns_iam_role_arn : null

    # ECS
    ecs_cluster_id                      = var.enable_ecs ? module.ecs_cluster[0].cluster_id : null
    ecs_cluster_name                    = var.enable_ecs ? module.ecs_cluster[0].cluster_name : null
    ecs_cluster_arn                     = var.enable_ecs ? module.ecs_cluster[0].cluster_arn : null
    ecs_task_execution_role_arn         = var.enable_ecs ? module.ecs_cluster[0].task_execution_role_arn : null
    ecs_task_role_arn                   = var.enable_ecs ? module.ecs_cluster[0].task_role_arn : null
    ecs_security_group_id               = var.enable_ecs ? module.ecs_cluster[0].security_group_id : null
    ecs_service_discovery_namespace_id  = var.enable_ecs ? module.ecs_cluster[0].service_discovery_namespace_id : null
    ecs_service_discovery_namespace_arn = var.enable_ecs ? module.ecs_cluster[0].service_discovery_namespace_arn : null

    # ALB
    alb_arn               = var.enable_alb ? module.alb[0].lb_arn : null
    alb_dns_name          = var.enable_alb ? module.alb[0].lb_dns_name : null
    alb_zone_id           = var.enable_alb ? module.alb[0].lb_zone_id : null
    alb_security_group_id = var.enable_alb ? module.alb_security_group[0].security_group_id : null

    # Bastion
    bastion_instance_id       = var.enable_bastion ? module.bastion[0].instance_id : null
    bastion_public_ip         = var.enable_bastion ? module.bastion[0].public_ip : null
    bastion_security_group_id = var.enable_bastion ? module.bastion_security_group[0].security_group_id : null
  }

  output_descriptions = {
    ecr_repository_urls                        = "Map of ECR repository URLs"
    ecr_repository_arns                        = "Map of ECR repository ARNs"
    ecr_repository_names                       = "Map of ECR repository names"
    eks_cluster_id                             = "EKS cluster ID"
    eks_cluster_name                           = "EKS cluster name"
    eks_cluster_endpoint                       = "EKS cluster endpoint URL"
    eks_cluster_version                        = "EKS cluster Kubernetes version"
    eks_cluster_security_group_id              = "EKS cluster security group ID"
    eks_oidc_provider_arn                      = "EKS OIDC provider ARN for IAM roles"
    eks_karpenter_iam_role_arn                 = "Karpenter IAM role ARN"
    eks_karpenter_instance_profile_name        = "Karpenter EC2 instance profile name"
    eks_aws_load_balancer_controller_iam_role_arn = "AWS Load Balancer Controller IAM role ARN"
    eks_external_dns_iam_role_arn              = "External DNS IAM role ARN"
    ecs_cluster_id                             = "ECS cluster ID"
    ecs_cluster_name                           = "ECS cluster name"
    ecs_cluster_arn                            = "ECS cluster ARN"
    ecs_task_execution_role_arn                = "ECS task execution role ARN"
    ecs_task_role_arn                          = "ECS task role ARN"
    ecs_security_group_id                      = "ECS tasks security group ID"
    ecs_service_discovery_namespace_id         = "ECS service discovery namespace ID"
    ecs_service_discovery_namespace_arn        = "ECS service discovery namespace ARN"
    alb_arn                                    = "Application Load Balancer ARN"
    alb_dns_name                               = "Application Load Balancer DNS name"
    alb_zone_id                                = "Application Load Balancer Route53 zone ID"
    alb_security_group_id                      = "Application Load Balancer security group ID"
    bastion_instance_id                        = "Bastion host EC2 instance ID"
    bastion_public_ip                          = "Bastion host public IP address"
    bastion_security_group_id                  = "Bastion host security group ID"
  }

  tags = var.common_tags

  depends_on = [
    module.ecr_repositories,
    module.eks_cluster,
    module.ecs_cluster,
    module.alb,
    module.bastion
  ]
}
