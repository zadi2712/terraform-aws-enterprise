# Compute Layer - UAT Environment Configuration
# Version: 2.0 - EKS and ECS configuration

aws_region   = "us-east-1"
environment  = "uat"
project_name = "mycompany"

common_tags = {
  Environment = "uat"
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
# EKS Configuration - UAT
################################################################################

eks_cluster_version = "1.31"

# Network Access - More restricted for UAT
eks_endpoint_private_access = true
eks_endpoint_public_access  = true
eks_public_access_cidrs     = ["0.0.0.0/0"] # Restrict to office/VPN

# Modern Features
eks_enable_pod_identity  = true
eks_authentication_mode  = "API_AND_CONFIG_MAP"

# Logging - Production-like for UAT
eks_cluster_log_types = ["api", "audit", "authenticator", "controllerManager"]
eks_log_retention_days = 14

# Node Groups - Production-like sizing
eks_node_groups = {
  on_demand = {
    instance_types = ["t3.large"]
    capacity_type  = "ON_DEMAND"
    desired_size   = 4
    min_size       = 2
    max_size       = 10
    disk_size      = 80

    labels = {
      role        = "on-demand"
      environment = "uat"
    }

    tags = {
      NodeGroup = "on-demand"
    }
  }

  spot = {
    instance_types = ["t3.large", "t3a.large"]
    capacity_type  = "SPOT"
    desired_size   = 2
    min_size       = 0
    max_size       = 8
    disk_size      = 80

    labels = {
      role        = "spot"
      environment = "uat"
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
eks_enable_efs_csi_driver = true

# Monitoring - More comprehensive for UAT
eks_enable_cloudwatch_observability = true
eks_enable_guardduty_agent          = false

# Controllers
eks_enable_aws_load_balancer_controller = true
eks_enable_external_dns                 = false
eks_external_dns_route53_zone_arns      = []

# Access Entries
eks_access_entries = {
  uat_team = {
    principal_arn = "arn:aws:iam::ACCOUNT_ID:role/UATTeam"
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
# ECS Configuration - UAT (Optional)
################################################################################

# Enable ECS if needed
# enable_ecs = true

ecs_capacity_providers = ["FARGATE", "FARGATE_SPOT"]

ecs_default_capacity_provider_strategy = [
  {
    capacity_provider = "FARGATE"
    weight            = 2
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
ecs_enable_service_discovery    = true
ecs_service_discovery_namespace = "uat.internal"

# Debugging - limited in UAT
ecs_enable_execute_command = false
ecs_log_retention_days     = 14

################################################################################
# Bastion Configuration - UAT
################################################################################

bastion_instance_type = "t3.micro"
bastion_key_name      = "uat-bastion-key"
bastion_allowed_cidrs = ["10.0.0.0/16"]

# Bastion storage and monitoring
bastion_allocate_eip            = true
bastion_enable_cloudwatch_agent = true  # Enable monitoring in UAT
bastion_root_volume_size        = 20

################################################################################
# Lambda Configuration - UAT
################################################################################

enable_lambda_infrastructure_functions = false  # Enable if needed
enable_health_check_lambda            = false

lambda_log_retention_days  = 14
lambda_enable_xray_tracing = true  # Enable tracing in UAT
lambda_use_arm64           = true
