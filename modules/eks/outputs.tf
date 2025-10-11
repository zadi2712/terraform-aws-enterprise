################################################################################
# EKS Module - Outputs
################################################################################

output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = aws_eks_cluster.this.id
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

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for IRSA"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC Provider"
  value       = aws_iam_openid_connect_provider.this.url
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "node_iam_role_arn" {
  description = "IAM role ARN of the EKS node groups"
  value       = aws_iam_role.node.arn
}

output "node_groups" {
  description = "Outputs from EKS node groups"
  value = {
    for k, v in aws_eks_node_group.this : k => {
      id     = v.id
      arn    = v.arn
      status = v.status
    }
  }
}

output "cluster_autoscaler_iam_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  value       = var.enable_cluster_autoscaler ? aws_iam_role.cluster_autoscaler[0].arn : null
}

output "cert_manager_iam_role_arn" {
  description = "IAM role ARN for Cert-Manager"
  value       = var.enable_cert_manager ? aws_iam_role.cert_manager[0].arn : null
}

output "aws_load_balancer_controller_iam_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = var.enable_aws_load_balancer_controller ? aws_iam_role.aws_load_balancer_controller[0].arn : null
}

output "ebs_csi_driver_iam_role_arn" {
  description = "IAM role ARN for EBS CSI Driver"
  value       = var.enable_ebs_csi_driver ? aws_iam_role.ebs_csi[0].arn : null
}

output "vpc_cni_iam_role_arn" {
  description = "IAM role ARN for VPC CNI"
  value       = aws_iam_role.vpc_cni.arn
}
