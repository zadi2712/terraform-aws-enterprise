################################################################################
# EKS Module - Outputs
# Version: 2.0 - Updated for EKS 1.31+ and modern features
################################################################################

################################################################################
# Cluster Outputs
################################################################################

output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = aws_eks_cluster.this.id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version for the cluster"
  value       = aws_eks_cluster.this.version
}

output "cluster_platform_version" {
  description = "The platform version for the cluster"
  value       = aws_eks_cluster.this.platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster"
  value       = aws_eks_cluster.this.status
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

################################################################################
# OIDC and Pod Identity Outputs
################################################################################

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for IRSA"
  value       = var.enable_pod_identity ? null : aws_iam_openid_connect_provider.this[0].arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC Provider"
  value       = var.enable_pod_identity ? null : aws_iam_openid_connect_provider.this[0].url
}

output "oidc_issuer" {
  description = "OIDC issuer URL without https:// prefix"
  value       = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

output "pod_identity_enabled" {
  description = "Whether EKS Pod Identity is enabled"
  value       = var.enable_pod_identity
}

################################################################################
# IAM Role Outputs
################################################################################

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "cluster_iam_role_name" {
  description = "IAM role name of the EKS cluster"
  value       = aws_iam_role.cluster.name
}

output "node_iam_role_arn" {
  description = "IAM role ARN of the EKS node groups"
  value       = aws_iam_role.node.arn
}

output "node_iam_role_name" {
  description = "IAM role name of the EKS node groups"
  value       = aws_iam_role.node.name
}

output "fargate_iam_role_arn" {
  description = "IAM role ARN for Fargate profiles"
  value       = length(var.fargate_profiles) > 0 ? aws_iam_role.fargate[0].arn : null
}

################################################################################
# Node Group Outputs
################################################################################

output "node_groups" {
  description = "Outputs from EKS node groups"
  value = {
    for k, v in aws_eks_node_group.this : k => {
      id                  = v.id
      arn                 = v.arn
      status              = v.status
      capacity_type       = v.capacity_type
      instance_types      = v.instance_types
      desired_size        = v.scaling_config[0].desired_size
      min_size            = v.scaling_config[0].min_size
      max_size            = v.scaling_config[0].max_size
      version             = v.version
      release_version     = v.release_version
    }
  }
}

output "fargate_profiles" {
  description = "Outputs from EKS Fargate profiles"
  value = {
    for k, v in aws_eks_fargate_profile.this : k => {
      id     = v.id
      arn    = v.arn
      status = v.status
    }
  }
}

################################################################################
# Add-on Outputs
################################################################################

output "addon_vpc_cni_version" {
  description = "Version of VPC CNI add-on"
  value       = aws_eks_addon.vpc_cni.addon_version
}

output "addon_coredns_version" {
  description = "Version of CoreDNS add-on"
  value       = aws_eks_addon.coredns.addon_version
}

output "addon_kube_proxy_version" {
  description = "Version of kube-proxy add-on"
  value       = aws_eks_addon.kube_proxy.addon_version
}

output "addon_ebs_csi_driver_version" {
  description = "Version of EBS CSI driver add-on"
  value       = var.enable_ebs_csi_driver ? aws_eks_addon.ebs_csi_driver[0].addon_version : null
}

output "addon_efs_csi_driver_version" {
  description = "Version of EFS CSI driver add-on"
  value       = var.enable_efs_csi_driver ? aws_eks_addon.efs_csi_driver[0].addon_version : null
}

output "addon_cloudwatch_observability_version" {
  description = "Version of CloudWatch Observability add-on"
  value       = var.enable_cloudwatch_observability ? aws_eks_addon.cloudwatch_observability[0].addon_version : null
}

output "addon_guardduty_agent_version" {
  description = "Version of GuardDuty agent add-on"
  value       = var.enable_guardduty_agent ? aws_eks_addon.guardduty_agent[0].addon_version : null
}

output "addon_pod_identity_agent_version" {
  description = "Version of Pod Identity agent add-on"
  value       = var.enable_pod_identity ? aws_eks_addon.pod_identity_agent[0].addon_version : null
}

################################################################################
# Component IAM Role Outputs
################################################################################

output "vpc_cni_iam_role_arn" {
  description = "IAM role ARN for VPC CNI"
  value       = var.enable_pod_identity ? aws_iam_role.vpc_cni_pod_identity[0].arn : aws_iam_role.vpc_cni[0].arn
}

output "ebs_csi_driver_iam_role_arn" {
  description = "IAM role ARN for EBS CSI Driver"
  value       = var.enable_ebs_csi_driver ? (var.enable_pod_identity ? aws_iam_role.ebs_csi_pod_identity[0].arn : aws_iam_role.ebs_csi[0].arn) : null
}

output "efs_csi_driver_iam_role_arn" {
  description = "IAM role ARN for EFS CSI Driver"
  value       = var.enable_efs_csi_driver ? (var.enable_pod_identity ? aws_iam_role.efs_csi_pod_identity[0].arn : aws_iam_role.efs_csi[0].arn) : null
}

output "cloudwatch_observability_iam_role_arn" {
  description = "IAM role ARN for CloudWatch Observability"
  value       = var.enable_cloudwatch_observability ? (var.enable_pod_identity ? aws_iam_role.cloudwatch_observability_pod_identity[0].arn : aws_iam_role.cloudwatch_observability[0].arn) : null
}

output "karpenter_iam_role_arn" {
  description = "IAM role ARN for Karpenter"
  value       = var.enable_karpenter ? aws_iam_role.karpenter[0].arn : null
}

output "karpenter_instance_profile_name" {
  description = "Instance profile name for Karpenter nodes"
  value       = var.enable_karpenter ? aws_iam_instance_profile.karpenter[0].name : null
}

output "cluster_autoscaler_iam_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  value       = var.enable_cluster_autoscaler && !var.enable_karpenter ? aws_iam_role.cluster_autoscaler[0].arn : null
}

output "aws_load_balancer_controller_iam_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = var.enable_aws_load_balancer_controller ? aws_iam_role.aws_load_balancer_controller[0].arn : null
}

output "external_dns_iam_role_arn" {
  description = "IAM role ARN for External DNS"
  value       = var.enable_external_dns ? aws_iam_role.external_dns[0].arn : null
}

################################################################################
# Configuration Helper Outputs
################################################################################

output "kubeconfig_command" {
  description = "Command to update local kubeconfig"
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${aws_eks_cluster.this.name}"
}

output "cluster_info" {
  description = "Comprehensive cluster information"
  value = {
    name                = aws_eks_cluster.this.name
    endpoint            = aws_eks_cluster.this.endpoint
    version             = aws_eks_cluster.this.version
    platform_version    = aws_eks_cluster.this.platform_version
    status              = aws_eks_cluster.this.status
    authentication_mode = var.authentication_mode
    pod_identity        = var.enable_pod_identity
    karpenter_enabled   = var.enable_karpenter
    region              = data.aws_region.current.name
  }
}

# Data source for current region
data "aws_region" "current" {}
