################################################################################
# Compute Layer - Variables
# Version: 2.0 - Added EKS configuration variables
################################################################################

################################################################################
# General Configuration
################################################################################

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

################################################################################
# ECR Configuration
################################################################################

variable "ecr_repositories" {
  description = "Map of ECR repositories to create"
  type = map(object({
    image_tag_mutability         = optional(string, "MUTABLE")
    scan_on_push                 = optional(bool, true)
    enable_enhanced_scanning     = optional(bool, false)
    scan_frequency               = optional(string, "SCAN_ON_PUSH")
    max_image_count              = optional(number, 100)
    lifecycle_policy             = optional(string, null)
    enable_cross_account_access  = optional(bool, false)
    allowed_account_ids          = optional(list(string), [])
    enable_lambda_pull           = optional(bool, false)
    enable_replication           = optional(bool, false)
    replication_destinations     = optional(list(object({
      region      = string
      registry_id = string
    })), [])
    enable_pull_through_cache         = optional(bool, false)
    pull_through_cache_prefix         = optional(string, "ecr-public")
    upstream_registry_url             = optional(string, "public.ecr.aws")
    pull_through_cache_credential_arn = optional(string, null)
  }))
  default = {}
}

variable "ecr_encryption_type" {
  description = "Encryption type for ECR repositories (AES256 or KMS)"
  type        = string
  default     = "AES256"
}

variable "ecr_enable_scan_findings_logging" {
  description = "Enable CloudWatch logging for ECR scan findings"
  type        = bool
  default     = false
}

variable "ecr_log_retention_days" {
  description = "Number of days to retain ECR scan findings logs"
  type        = number
  default     = 30
}

################################################################################
# Feature Toggles
################################################################################

variable "enable_eks" {
  description = "Enable EKS cluster"
  type        = bool
  default     = true
}

variable "enable_ecs" {
  description = "Enable ECS cluster"
  type        = bool
  default     = false
}

variable "enable_alb" {
  description = "Enable Application Load Balancer"
  type        = bool
  default     = true
}

variable "enable_bastion" {
  description = "Enable bastion host"
  type        = bool
  default     = false
}

variable "enable_container_insights" {
  description = "Enable Container Insights for ECS"
  type        = bool
  default     = true
}

################################################################################
# ECS Configuration
################################################################################

variable "ecs_capacity_providers" {
  description = "ECS capacity providers"
  type        = list(string)
  default     = ["FARGATE", "FARGATE_SPOT"]
}

variable "ecs_default_capacity_provider_strategy" {
  description = "ECS default capacity provider strategy"
  type = list(object({
    capacity_provider = string
    weight            = number
    base              = optional(number, 0)
  }))
  default = [
    {
      capacity_provider = "FARGATE"
      weight            = 1
      base              = 1
    }
  ]
}

variable "ecs_create_security_group" {
  description = "Whether to create a security group for ECS tasks"
  type        = bool
  default     = true
}

variable "ecs_task_container_port" {
  description = "Container port for ECS tasks"
  type        = number
  default     = 8080
}

variable "ecs_create_task_execution_role" {
  description = "Whether to create ECS task execution role"
  type        = bool
  default     = true
}

variable "ecs_create_task_role" {
  description = "Whether to create ECS task role"
  type        = bool
  default     = true
}

variable "ecs_enable_service_discovery" {
  description = "Enable AWS Cloud Map service discovery for ECS"
  type        = bool
  default     = false
}

variable "ecs_service_discovery_namespace" {
  description = "ECS service discovery namespace"
  type        = string
  default     = "local"
}

variable "ecs_enable_execute_command" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = false
}

variable "ecs_log_retention_days" {
  description = "CloudWatch log retention for ECS Exec"
  type        = number
  default     = 7
}

################################################################################
# EKS Configuration
################################################################################

variable "eks_cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

variable "eks_endpoint_private_access" {
  description = "Enable private API endpoint for EKS"
  type        = bool
  default     = true
}

variable "eks_endpoint_public_access" {
  description = "Enable public API endpoint for EKS"
  type        = bool
  default     = true
}

variable "eks_public_access_cidrs" {
  description = "CIDRs allowed to access public API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_enable_pod_identity" {
  description = "Enable EKS Pod Identity"
  type        = bool
  default     = true
}

variable "eks_authentication_mode" {
  description = "Authentication mode for EKS cluster"
  type        = string
  default     = "API_AND_CONFIG_MAP"
}

variable "eks_cluster_log_types" {
  description = "EKS control plane logging types"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "eks_log_retention_days" {
  description = "CloudWatch log retention for EKS"
  type        = number
  default     = 7
}

variable "eks_node_groups" {
  description = "EKS node group configurations"
  type        = any
  default     = {}
}

variable "eks_fargate_profiles" {
  description = "EKS Fargate profile configurations"
  type        = any
  default     = {}
}

variable "eks_enable_karpenter" {
  description = "Enable Karpenter for EKS autoscaling"
  type        = bool
  default     = true
}

variable "eks_enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler for EKS"
  type        = bool
  default     = false
}

variable "eks_enable_ebs_csi_driver" {
  description = "Enable EBS CSI driver for EKS"
  type        = bool
  default     = true
}

variable "eks_enable_efs_csi_driver" {
  description = "Enable EFS CSI driver for EKS"
  type        = bool
  default     = false
}

variable "eks_enable_cloudwatch_observability" {
  description = "Enable CloudWatch Observability for EKS"
  type        = bool
  default     = true
}

variable "eks_enable_guardduty_agent" {
  description = "Enable GuardDuty agent for EKS"
  type        = bool
  default     = false
}

variable "eks_enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller for EKS"
  type        = bool
  default     = true
}

variable "eks_enable_external_dns" {
  description = "Enable External DNS for EKS"
  type        = bool
  default     = false
}

variable "eks_external_dns_route53_zone_arns" {
  description = "Route53 zone ARNs for External DNS"
  type        = list(string)
  default     = []
}

variable "eks_access_entries" {
  description = "EKS access entries for IAM principals"
  type        = any
  default     = {}
}

################################################################################
# Bastion Host Configuration
################################################################################

variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "bastion_ami_id" {
  description = "AMI ID for bastion host"
  type        = string
  default     = null
}

variable "bastion_key_name" {
  description = "SSH key name for bastion host"
  type        = string
  default     = null
}

variable "bastion_allowed_cidrs" {
  description = "CIDRs allowed to SSH to bastion"
  type        = list(string)
  default     = []
}

variable "bastion_user_data" {
  description = "User data script for bastion host (base64 encoded)"
  type        = string
  default     = null
}

variable "bastion_allocate_eip" {
  description = "Allocate Elastic IP for bastion host"
  type        = bool
  default     = true
}

variable "bastion_enable_cloudwatch_agent" {
  description = "Enable CloudWatch agent on bastion host"
  type        = bool
  default     = false
}

variable "bastion_root_volume_size" {
  description = "Root volume size for bastion host (GB)"
  type        = number
  default     = 20
}

################################################################################
# Lambda Configuration
################################################################################

variable "enable_lambda_infrastructure_functions" {
  description = "Enable Lambda infrastructure functions (health checks, cleanup tasks)"
  type        = bool
  default     = false
}

variable "enable_health_check_lambda" {
  description = "Enable health check Lambda function"
  type        = bool
  default     = false
}

variable "lambda_health_check_filename" {
  description = "Path to Lambda health check deployment package"
  type        = string
  default     = null
}

variable "lambda_health_check_handler" {
  description = "Lambda health check handler"
  type        = string
  default     = "index.handler"
}

variable "lambda_health_check_runtime" {
  description = "Lambda health check runtime"
  type        = string
  default     = "python3.11"
}

variable "lambda_health_check_memory" {
  description = "Lambda health check memory in MB"
  type        = number
  default     = 128
}

variable "lambda_health_check_timeout" {
  description = "Lambda health check timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_health_check_vpc_enabled" {
  description = "Enable VPC configuration for Lambda health check"
  type        = bool
  default     = false
}

variable "lambda_health_check_policy_arns" {
  description = "Additional IAM policy ARNs for Lambda health check"
  type        = map(string)
  default     = {}
}

variable "lambda_health_check_environment_variables" {
  description = "Additional environment variables for Lambda health check"
  type        = map(string)
  default     = {}
}

variable "lambda_log_retention_days" {
  description = "CloudWatch log retention for Lambda functions"
  type        = number
  default     = 7
}

variable "lambda_enable_xray_tracing" {
  description = "Enable X-Ray tracing for Lambda functions"
  type        = bool
  default     = false
}

variable "lambda_use_arm64" {
  description = "Use ARM64 architecture for Lambda (20% cost savings)"
  type        = bool
  default     = true
}
