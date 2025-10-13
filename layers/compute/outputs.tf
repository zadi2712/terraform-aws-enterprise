################################################################################
# Compute Layer - Outputs
# Version: 2.0 - Added EKS outputs
################################################################################

################################################################################
# ECR Outputs
################################################################################

output "ecr_repository_urls" {
  description = "Map of ECR repository URLs"
  value = {
    for k, v in module.ecr_repositories : k => v.repository_url
  }
}

output "ecr_repository_arns" {
  description = "Map of ECR repository ARNs"
  value = {
    for k, v in module.ecr_repositories : k => v.repository_arn
  }
}

output "ecr_repository_names" {
  description = "Map of ECR repository names"
  value = {
    for k, v in module.ecr_repositories : k => v.repository_name
  }
}

output "ecr_registry_ids" {
  description = "Map of ECR registry IDs"
  value = {
    for k, v in module.ecr_repositories : k => v.repository_registry_id
  }
}

################################################################################
# EKS Outputs
################################################################################

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = var.enable_eks ? module.eks_cluster[0].cluster_id : null
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = var.enable_eks ? module.eks_cluster[0].cluster_name : null
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = var.enable_eks ? module.eks_cluster[0].cluster_endpoint : null
}

output "eks_cluster_version" {
  description = "EKS cluster version"
  value       = var.enable_eks ? module.eks_cluster[0].cluster_version : null
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = var.enable_eks ? module.eks_cluster[0].cluster_security_group_id : null
}

output "eks_cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = var.enable_eks ? module.eks_cluster[0].cluster_certificate_authority_data : null
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  value       = var.enable_eks ? module.eks_cluster[0].oidc_provider_arn : null
}

output "eks_node_groups" {
  description = "EKS node groups"
  value       = var.enable_eks ? module.eks_cluster[0].node_groups : null
}

output "eks_fargate_profiles" {
  description = "EKS Fargate profiles"
  value       = var.enable_eks ? module.eks_cluster[0].fargate_profiles : null
}

output "eks_karpenter_iam_role_arn" {
  description = "Karpenter IAM role ARN"
  value       = var.enable_eks ? module.eks_cluster[0].karpenter_iam_role_arn : null
}

output "eks_karpenter_instance_profile_name" {
  description = "Karpenter instance profile name"
  value       = var.enable_eks ? module.eks_cluster[0].karpenter_instance_profile_name : null
}

output "eks_aws_load_balancer_controller_iam_role_arn" {
  description = "AWS Load Balancer Controller IAM role ARN"
  value       = var.enable_eks ? module.eks_cluster[0].aws_load_balancer_controller_iam_role_arn : null
}

output "eks_external_dns_iam_role_arn" {
  description = "External DNS IAM role ARN"
  value       = var.enable_eks ? module.eks_cluster[0].external_dns_iam_role_arn : null
}

output "eks_kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = var.enable_eks ? module.eks_cluster[0].kubeconfig_command : null
}

output "eks_cluster_info" {
  description = "Comprehensive EKS cluster information"
  value       = var.enable_eks ? module.eks_cluster[0].cluster_info : null
}

################################################################################
# ECS Outputs
################################################################################

output "ecs_cluster_id" {
  description = "ECS cluster ID"
  value       = var.enable_ecs ? module.ecs_cluster[0].cluster_id : null
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = var.enable_ecs ? module.ecs_cluster[0].cluster_name : null
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = var.enable_ecs ? module.ecs_cluster[0].cluster_arn : null
}

################################################################################
# ALB Outputs
################################################################################

output "alb_arn" {
  description = "ALB ARN"
  value       = var.enable_alb ? module.alb[0].lb_arn : null
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = var.enable_alb ? module.alb[0].lb_dns_name : null
}

output "alb_zone_id" {
  description = "ALB Zone ID"
  value       = var.enable_alb ? module.alb[0].lb_zone_id : null
}

output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = var.enable_alb ? module.alb_security_group[0].security_group_id : null
}

################################################################################
# Bastion Outputs
################################################################################

output "bastion_instance_id" {
  description = "Bastion instance ID"
  value       = var.enable_bastion ? module.bastion[0].instance_id : null
}

output "bastion_public_ip" {
  description = "Bastion public IP"
  value       = var.enable_bastion ? module.bastion[0].public_ip : null
}

output "bastion_security_group_id" {
  description = "Bastion security group ID"
  value       = var.enable_bastion ? module.bastion_security_group[0].security_group_id : null
}
