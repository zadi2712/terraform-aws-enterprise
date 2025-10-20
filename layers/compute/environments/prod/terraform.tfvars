# Compute Layer - Production Environment Configuration
# Version: 2.0 - EKS production-grade configuration

aws_region   = "us-east-1"
environment  = "prod"
project_name = "mycompany"

common_tags = {
  Environment = "prod"
  Project     = "mycompany"
  ManagedBy   = "terraform"
  Layer       = "compute"
  CostCenter  = "engineering"
  Compliance  = "required"
}

################################################################################
# Feature Toggles
################################################################################

enable_eks     = true
enable_ecs     = false
enable_alb     = true
enable_bastion = true

################################################################################
# EKS Configuration - Production
################################################################################

eks_cluster_version = "1.31"

# Network Access - Secure production configuration
eks_endpoint_private_access = true
eks_endpoint_public_access  = true
eks_public_access_cidrs     = ["203.0.113.0/24"] # Your office/VPN CIDR only

# Modern Features
eks_enable_pod_identity  = true
eks_authentication_mode  = "API_AND_CONFIG_MAP"

# Logging - Full logging for production
eks_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
eks_log_retention_days = 30

# Node Groups - Multi-AZ, mixed instance types for resilience
eks_node_groups = {
  # On-demand nodes for critical workloads
  on_demand = {
    instance_types = ["t3.large"]
    capacity_type  = "ON_DEMAND"
    desired_size   = 6
    min_size       = 3
    max_size       = 20
    disk_size      = 100

    labels = {
      role        = "on-demand"
      environment = "prod"
      criticality = "high"
    }

    tags = {
      NodeGroup   = "on-demand"
      Criticality = "high"
    }
  }

  # Spot nodes for non-critical workloads
  spot = {
    instance_types = ["t3.large", "t3a.large", "t3.xlarge"]
    capacity_type  = "SPOT"
    desired_size   = 3
    min_size       = 0
    max_size       = 15
    disk_size      = 100

    labels = {
      role        = "spot"
      environment = "prod"
      criticality = "low"
    }

    taints = [
      {
        key    = "spot"
        value  = "true"
        effect = "NoSchedule"
      }
    ]

    tags = {
      NodeGroup   = "spot"
      Criticality = "low"
    }
  }

  # Compute-optimized for specific workloads
  compute = {
    instance_types = ["c6i.2xlarge"]
    capacity_type  = "ON_DEMAND"
    desired_size   = 0
    min_size       = 0
    max_size       = 10
    disk_size      = 100

    labels = {
      role         = "compute"
      environment  = "prod"
      workload_type = "compute-intensive"
    }

    taints = [
      {
        key    = "dedicated"
        value  = "compute"
        effect = "NoSchedule"
      }
    ]

    tags = {
      NodeGroup    = "compute"
      WorkloadType = "compute-intensive"
    }
  }
}

# Fargate Profiles - For specific workloads
eks_fargate_profiles = {
  # System workloads on Fargate
  kube_system = {
    selectors = [
      {
        namespace = "kube-system"
        labels = {
          fargate = "true"
        }
      }
    ]
  }
}

# Autoscaling - Karpenter for intelligent scaling
eks_enable_karpenter          = true
eks_enable_cluster_autoscaler = false

# Storage Drivers
eks_enable_ebs_csi_driver = true
eks_enable_efs_csi_driver = true # Enable for shared storage needs

# Monitoring - Full observability for production
eks_enable_cloudwatch_observability = true
eks_enable_guardduty_agent          = true

# Controllers
eks_enable_aws_load_balancer_controller = true
eks_enable_external_dns                 = true
eks_external_dns_route53_zone_arns = [
  "arn:aws:route53:::hostedzone/Z1234567890ABC"
]

# Access Entries - Strict RBAC for production
eks_access_entries = {
  # Platform team - Full admin access
  platform_admin = {
    principal_arn = "arn:aws:iam::ACCOUNT_ID:role/PlatformTeam"
    type          = "STANDARD"

    policy_associations = [
      {
        policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope_type = "cluster"
      }
    ]
  }

  # Application teams - Namespace-specific access
  app_team_prod = {
    principal_arn = "arn:aws:iam::ACCOUNT_ID:role/AppTeamProd"
    type          = "STANDARD"

    policy_associations = [
      {
        policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
        access_scope_type = "namespace"
        namespaces        = ["production", "apps"]
      }
    ]
  }

  # SRE team - Cluster-wide view, namespace-specific edit
  sre_team = {
    principal_arn = "arn:aws:iam::ACCOUNT_ID:role/SRETeam"
    type          = "STANDARD"

    policy_associations = [
      {
        policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
        access_scope_type = "cluster"
      },
      {
        policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
        access_scope_type = "namespace"
        namespaces        = ["monitoring", "logging"]
      }
    ]
  }

  # Read-only auditors
  auditors = {
    principal_arn = "arn:aws:iam::ACCOUNT_ID:role/Auditors"
    type          = "STANDARD"

    policy_associations = [
      {
        policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
        access_scope_type = "cluster"
      }
    ]
  }
}

################################################################################
# ECS Configuration - Production (Optional)
################################################################################

# Enable ECS if needed for production
# enable_ecs = true

# ECS capacity providers - balanced strategy for production
ecs_capacity_providers = ["FARGATE", "FARGATE_SPOT"]

ecs_default_capacity_provider_strategy = [
  {
    capacity_provider = "FARGATE"
    weight            = 2
    base              = 2
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

# Service discovery - enable for microservices architectures
ecs_enable_service_discovery    = true
ecs_service_discovery_namespace = "services.internal"

# Debugging - disabled in production for security
ecs_enable_execute_command = false
ecs_log_retention_days     = 30

################################################################################
# Bastion Configuration - Production
################################################################################

bastion_instance_type = "t3.micro"
bastion_key_name      = "prod-bastion-key"
bastion_allowed_cidrs = ["10.0.0.0/16"] # Restrict to corporate network only

# Bastion storage and monitoring
bastion_allocate_eip            = true   # Static IP for production
bastion_enable_cloudwatch_agent = true   # Full monitoring in production
bastion_root_volume_size        = 30     # Larger volume for logs
