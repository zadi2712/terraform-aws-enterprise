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
  description = "User data script for bastion host"
  type        = string
  default     = null
}
