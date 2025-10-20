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
# ECS Configuration - Development (Optional)
################################################################################

# Enable ECS if needed for development
# enable_ecs = true

# ECS capacity providers - prefer Spot for dev to save costs
ecs_capacity_providers = ["FARGATE", "FARGATE_SPOT"]

ecs_default_capacity_provider_strategy = [
  {
    capacity_provider = "FARGATE_SPOT"
    weight            = 2
    base              = 0
  },
  {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
]

# Network and security
ecs_create_security_group = true
ecs_task_container_port   = 8080

# IAM roles
ecs_create_task_execution_role = true
ecs_create_task_role           = true

# Service discovery - enable for microservices
ecs_enable_service_discovery    = false
ecs_service_discovery_namespace = "dev.local"

# Debugging - enable in dev
ecs_enable_execute_command = true
ecs_log_retention_days     = 3

################################################################################
# Bastion Configuration - Development
################################################################################

bastion_instance_type = "t3.micro"
bastion_key_name      = "dev-bastion-key"
bastion_allowed_cidrs = ["10.0.0.0/8"] # Your VPN/Office CIDR

# Bastion storage and monitoring
bastion_allocate_eip            = true   # Static IP for easy access
bastion_enable_cloudwatch_agent = false  # Disable in dev to save costs
bastion_root_volume_size        = 20     # GB

################################################################################
# Lambda Configuration - Development
################################################################################

# Lambda infrastructure functions (optional)
enable_lambda_infrastructure_functions = false  # Enable if needed
enable_health_check_lambda            = false  # Example function

# Lambda global settings
lambda_log_retention_days   = 3     # Short retention for dev
lambda_enable_xray_tracing  = false # Disable to save costs
lambda_use_arm64            = true  # 20% cost savings

# Health check Lambda configuration (if enabled)
# lambda_health_check_filename = "lambda/health-check.zip"
# lambda_health_check_handler  = "index.handler"
# lambda_health_check_runtime  = "python3.11"
# lambda_health_check_memory   = 128
# lambda_health_check_timeout  = 30
# lambda_health_check_vpc_enabled = false
