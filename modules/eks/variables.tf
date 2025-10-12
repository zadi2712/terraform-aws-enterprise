################################################################################
# EKS Module - Variables
# Version: 2.0 - Updated for EKS 1.31+ and modern features
################################################################################

################################################################################
# Core Cluster Configuration
################################################################################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "cluster_support_type" {
  description = "Support type for the cluster (STANDARD or EXTENDED)"
  type        = string
  default     = "STANDARD"
  validation {
    condition     = contains(["STANDARD", "EXTENDED"], var.cluster_support_type)
    error_message = "cluster_support_type must be either STANDARD or EXTENDED."
  }
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)
}

################################################################################
# Network Configuration
################################################################################

variable "endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_security_group_ids" {
  description = "List of security group IDs for the cluster"
  type        = list(string)
  default     = []
}

variable "service_ipv4_cidr" {
  description = "The CIDR block to assign Kubernetes service IP addresses from"
  type        = string
  default     = null
}

variable "ip_family" {
  description = "The IP family used to assign Kubernetes pod and service addresses (ipv4 or ipv6)"
  type        = string
  default     = "ipv4"
  validation {
    condition     = contains(["ipv4", "ipv6"], var.ip_family)
    error_message = "ip_family must be either ipv4 or ipv6."
  }
}

variable "create_node_security_group_rules" {
  description = "Create security group rules for node-to-node communication"
  type        = bool
  default     = true
}

################################################################################
# Authentication and Access
################################################################################

variable "authentication_mode" {
  description = "Authentication mode for the cluster (API, API_AND_CONFIG_MAP, or CONFIG_MAP)"
  type        = string
  default     = "API_AND_CONFIG_MAP"
  validation {
    condition     = contains(["API", "API_AND_CONFIG_MAP", "CONFIG_MAP"], var.authentication_mode)
    error_message = "authentication_mode must be API, API_AND_CONFIG_MAP, or CONFIG_MAP."
  }
}

variable "bootstrap_cluster_creator_admin_permissions" {
  description = "Bootstrap the cluster creator with admin permissions"
  type        = bool
  default     = true
}

variable "access_entries" {
  description = "Map of access entries to add to the cluster"
  type        = any
  default     = {}
}

variable "enable_vpc_resource_controller" {
  description = "Enable VPC Resource Controller for security group management"
  type        = bool
  default     = true
}

################################################################################
# Logging and Monitoring
################################################################################

variable "cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 7
}

################################################################################
# Encryption
################################################################################

variable "kms_key_arn" {
  description = "ARN of KMS key for envelope encryption"
  type        = string
  default     = null
}

################################################################################
# Node Groups Configuration
################################################################################

variable "node_groups" {
  description = "Map of node group configurations"
  type        = any
  default     = {}
}

variable "enable_ssm_on_nodes" {
  description = "Enable AWS Systems Manager on nodes"
  type        = bool
  default     = true
}

################################################################################
# Fargate Profiles
################################################################################

variable "fargate_profiles" {
  description = "Map of Fargate profile configurations"
  type        = any
  default     = {}
}

################################################################################
# EKS Add-ons
################################################################################

variable "vpc_cni_version" {
  description = "Version of the VPC CNI add-on"
  type        = string
  default     = null
}

variable "coredns_version" {
  description = "Version of the CoreDNS add-on"
  type        = string
  default     = null
}

variable "coredns_configuration_values" {
  description = "Configuration values for CoreDNS add-on"
  type        = string
  default     = null
}

variable "kube_proxy_version" {
  description = "Version of the kube-proxy add-on"
  type        = string
  default     = null
}

variable "enable_ebs_csi_driver" {
  description = "Enable EBS CSI driver add-on"
  type        = bool
  default     = true
}

variable "ebs_csi_driver_version" {
  description = "Version of the EBS CSI driver add-on"
  type        = string
  default     = null
}

variable "enable_efs_csi_driver" {
  description = "Enable EFS CSI driver add-on"
  type        = bool
  default     = false
}

variable "efs_csi_driver_version" {
  description = "Version of the EFS CSI driver add-on"
  type        = string
  default     = null
}

variable "enable_cloudwatch_observability" {
  description = "Enable Amazon CloudWatch Observability add-on"
  type        = bool
  default     = false
}

variable "cloudwatch_observability_version" {
  description = "Version of the CloudWatch Observability add-on"
  type        = string
  default     = null
}

variable "enable_guardduty_agent" {
  description = "Enable Amazon GuardDuty EKS Runtime Monitoring"
  type        = bool
  default     = false
}

variable "guardduty_agent_version" {
  description = "Version of the GuardDuty agent add-on"
  type        = string
  default     = null
}

################################################################################
# Pod Identity (Modern IRSA Alternative)
################################################################################

variable "enable_pod_identity" {
  description = "Enable EKS Pod Identity (modern alternative to IRSA)"
  type        = bool
  default     = true
}

variable "pod_identity_agent_version" {
  description = "Version of the Pod Identity Agent add-on"
  type        = string
  default     = null
}

################################################################################
# Autoscaling Configuration
################################################################################

variable "enable_karpenter" {
  description = "Enable Karpenter for autoscaling (modern alternative to Cluster Autoscaler)"
  type        = bool
  default     = true
}

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler (traditional autoscaling, disabled if Karpenter is enabled)"
  type        = bool
  default     = false
}

################################################################################
# AWS Load Balancer Controller
################################################################################

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "aws_load_balancer_controller_policy_json" {
  description = "Custom IAM policy JSON for AWS Load Balancer Controller (optional)"
  type        = string
  default     = null
}

################################################################################
# External DNS
################################################################################

variable "enable_external_dns" {
  description = "Enable External DNS for automatic DNS record management"
  type        = bool
  default     = false
}

variable "external_dns_route53_zone_arns" {
  description = "List of Route53 zone ARNs for External DNS to manage"
  type        = list(string)
  default     = ["arn:aws:route53:::hostedzone/*"]
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
