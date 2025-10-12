# Compute Layer - Development Environment Configuration
# Version: 2.0 - EKS-focused configuration

aws_region   = "us-east-1"
environment  = "dev"
project_name = "mycompany"

common_tags = {
  Environment = "dev"
  Project     = "mycompany"
  ManagedBy   = "terraform"
  Layer       = "compute"
  CostCenter  = "engineering"
}

################################################################################
# Feature Toggles
################################################################################

enable_eks     = true
enable_ecs     = false
enable_alb     = true
enable_bastion = true

################################################################################
# EKS Configuration - Development
################################################################################

eks_cluster_version = "1.31"

# Network Access
eks_endpoint_private_access = true
eks_endpoint_public_access  = true
eks_public_access_cidrs     = ["0.0.0.0/0"] # Restrict in production

# Modern Features
eks_enable_pod_identity  = true
eks_authentication_mode  = "API_AND_CONFIG_MAP"

# Logging - Reduced for dev to save costs
eks_cluster_log_types = ["api", "audit"]
eks_log_retention_days = 3

# Node Groups - Cost-optimized for development
eks_node_groups = {
  general = {
    instance_types = ["t3.medium", "t3a.medium"]
    capacity_type  = "SPOT" # Use spot for dev to save costs
    desired_size   = 2
    min_size       = 1
    max_size       = 5
    disk_size      = 50

    labels = {
      role        = "general"
      environment = "dev"
    }

    tags = {
      NodeGroup = "general"
    }
  }
}

# Fargate Profiles - Optional for dev
eks_fargate_profiles = {}

# Autoscaling
eks_enable_karpenter          = true
eks_enable_cluster_autoscaler = false

# Storage Drivers
eks_enable_ebs_csi_driver = true
eks_enable_efs_csi_driver = false

# Monitoring - Basic for dev
eks_enable_cloudwatch_observability = false
eks_enable_guardduty_agent          = false

# Controllers
eks_enable_aws_load_balancer_controller = true
eks_enable_external_dns                 = false
eks_external_dns_route53_zone_arns      = []

# Access Entries - Developer access
eks_access_entries = {
  developers = {
    principal_arn = "arn:aws:iam::ACCOUNT_ID:role/Developers"
    type          = "STANDARD"

    policy_associations = [
      {
        policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope_type = "cluster"
      }
    ]
  }
}

################################################################################
# Bastion Configuration
################################################################################

bastion_instance_type = "t3.micro"
bastion_key_name      = "dev-bastion-key"
bastion_allowed_cidrs = ["10.0.0.0/8"] # Your VPN/Office CIDR
