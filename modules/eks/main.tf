################################################################################
# EKS Module - Main Configuration
# Description: EKS Cluster configuration
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Module    = "eks"
      ManagedBy = "terraform"
    }
  )
}

# Add your resource configurations here
# Resources: aws_eks_cluster, aws_eks_node_group, aws_eks_addon
