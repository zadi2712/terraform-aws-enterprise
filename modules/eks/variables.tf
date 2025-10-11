################################################################################
# EKS Module - Variables
################################################################################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)
}

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

variable "kms_key_arn" {
  description = "ARN of KMS key for envelope encryption"
  type        = string
  default     = null
}

variable "node_groups" {
  description = "Map of node group configurations"
  type        = any
  default     = {}
}

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

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "enable_cert_manager" {
  description = "Enable Cert-Manager"
  type        = bool
  default     = true
}

variable "cert_manager_route53_zone_arns" {
  description = "List of Route53 zone ARNs for Cert-Manager to manage"
  type        = list(string)
  default     = ["arn:aws:route53:::hostedzone/*"]
}

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

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
