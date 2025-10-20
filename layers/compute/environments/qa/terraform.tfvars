# Compute Layer - QA Environment Configuration
# Version: 2.0 - EKS and ECS configuration

aws_region   = "us-east-1"
environment  = "qa"
project_name = "mycompany"

common_tags = {
  Environment = "qa"
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
# EKS Configuration - QA
################################################################################

eks_cluster_version = "1.31"

# Network Access
eks_endpoint_private_access = true
eks_endpoint_public_access  = true
eks_public_access_cidrs     = ["0.0.0.0/0"] # Restrict as needed

# Modern Features
eks_enable_pod_identity  = true
eks_authentication_mode  = "API_AND_CONFIG_MAP"

# Logging - Moderate for QA
eks_cluster_log_types = ["api", "audit", "authenticator"]
eks_log_retention_days = 7

# Node Groups - Similar to production but smaller
eks_node_groups = {
  general = {
    instance_types = ["t3.medium", "t3a.medium"]
    capacity_type  = "ON_DEMAND"
    desired_size   = 3
    min_size       = 2
    max_size       = 8
    disk_size      = 50

    labels = {
      role        = "general"
      environment = "qa"
    }

    tags = {
      NodeGroup = "general"
    }
  }

  spot = {
    instance_types = ["t3.medium", "t3a.medium"]
    capacity_type  = "SPOT"
    desired_size   = 1
    min_size       = 0
    max_size       = 5
    disk_size      = 50

    labels = {
      role        = "spot"
      environment = "qa"
    }

    taints = [
      {
        key    = "spot"
        value  = "true"
        effect = "NoSchedule"
      }
    ]

    tags = {
      NodeGroup = "spot"
    }
  }
}

# Fargate Profiles
eks_fargate_profiles = {}

# Autoscaling
eks_enable_karpenter          = true
eks_enable_cluster_autoscaler = false

# Storage Drivers
eks_enable_ebs_csi_driver = true
eks_enable_efs_csi_driver = false

# Monitoring
eks_enable_cloudwatch_observability = false
eks_enable_guardduty_agent          = false

# Controllers
eks_enable_aws_load_balancer_controller = true
eks_enable_external_dns                 = false
eks_external_dns_route53_zone_arns      = []

# Access Entries
eks_access_entries = {
  qa_team = {
    principal_arn = "arn:aws:iam::ACCOUNT_ID:role/QATeam"
    type          = "STANDARD"

    policy_associations = [
      {
        policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
        access_scope_type = "cluster"
      }
    ]
  }
}

################################################################################
# ECS Configuration - QA (Optional)
################################################################################

# Enable ECS if needed
# enable_ecs = true

ecs_capacity_providers = ["FARGATE", "FARGATE_SPOT"]

ecs_default_capacity_provider_strategy = [
  {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  },
  {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
    base              = 0
  }
]

# Network and security
ecs_create_security_group = true
ecs_task_container_port   = 8080

# IAM roles
ecs_create_task_execution_role = true
ecs_create_task_role           = true

# Service discovery
ecs_enable_service_discovery    = false
ecs_service_discovery_namespace = "qa.local"

# Debugging
ecs_enable_execute_command = true
ecs_log_retention_days     = 7

################################################################################
# Bastion Configuration - QA
################################################################################

bastion_instance_type = "t3.micro"
bastion_key_name      = "qa-bastion-key"
bastion_allowed_cidrs = ["10.0.0.0/8"]

# Bastion storage and monitoring
bastion_allocate_eip            = true
bastion_enable_cloudwatch_agent = false
bastion_root_volume_size        = 20
