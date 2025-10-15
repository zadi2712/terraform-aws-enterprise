################################################################################
# EKS Module - Main Configuration
# Description: Enterprise-grade EKS Cluster with managed node groups, Fargate,
#              Pod Identity, and comprehensive add-ons
# Version: 2.0 - Updated for EKS 1.31 and modern features
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Module    = "eks"
      ManagedBy = "terraform"
    }
  )

  # Generate OIDC issuer without https:// prefix
  oidc_issuer = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

################################################################################
# EKS Cluster
################################################################################

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = var.cluster_security_group_ids
  }

  enabled_cluster_log_types = var.cluster_log_types

  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }

  # Enable EKS Access Config for modern authentication
  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions
  }

  # Upgrade policy for managed add-ons
  upgrade_policy {
    support_type = var.cluster_support_type
  }

  # Enable Kubernetes API server audit logging to CloudWatch
  dynamic "kubernetes_network_config" {
    for_each = var.service_ipv4_cidr != null ? [1] : []
    content {
      service_ipv4_cidr = var.service_ipv4_cidr
      ip_family         = var.ip_family
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
  ]

  tags = local.common_tags
}

################################################################################
# EKS Access Entries (Modern RBAC Management)
################################################################################

resource "aws_eks_access_entry" "this" {
  for_each = var.access_entries

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value.principal_arn
  type          = lookup(each.value, "type", "STANDARD")
  user_name     = lookup(each.value, "user_name", null)

  tags = local.common_tags
}

resource "aws_eks_access_policy_association" "this" {
  for_each = {
    for k, v in var.access_entries : k => v
    if lookup(v, "policy_associations", []) != []
  }

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value.principal_arn

  dynamic "policy_association" {
    for_each = lookup(each.value, "policy_associations", [])
    content {
      policy_arn = policy_association.value.policy_arn
      access_scope {
        type       = lookup(policy_association.value, "access_scope_type", "cluster")
        namespaces = lookup(policy_association.value, "namespaces", [])
      }
    }
  }

  depends_on = [aws_eks_access_entry.this]
}

################################################################################
# EKS Cluster IAM Role
################################################################################

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# Optional: VPC Resource Controller permissions for security groups
resource "aws_iam_role_policy_attachment" "cluster_vpc_resource_controller" {
  count = var.enable_vpc_resource_controller ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

################################################################################
# EKS Node Groups
################################################################################

resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-${each.key}"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = lookup(each.value, "subnet_ids", var.subnet_ids)
  version         = lookup(each.value, "version", var.cluster_version)

  scaling_config {
    desired_size = lookup(each.value, "desired_size", 2)
    min_size     = lookup(each.value, "min_size", 1)
    max_size     = lookup(each.value, "max_size", 10)
  }

  update_config {
    max_unavailable_percentage = lookup(each.value, "max_unavailable_percentage", 33)
  }

  instance_types = lookup(each.value, "instance_types", ["t3.medium"])
  capacity_type  = lookup(each.value, "capacity_type", "ON_DEMAND")
  disk_size      = lookup(each.value, "disk_size", 50)
  ami_type       = lookup(each.value, "ami_type", "AL2_x86_64")

  labels = merge(
    lookup(each.value, "labels", {}),
    { "node-group" = each.key }
  )

  dynamic "taint" {
    for_each = lookup(each.value, "taints", [])
    content {
      key    = taint.value.key
      value  = lookup(taint.value, "value", null)
      effect = taint.value.effect
    }
  }

  # Launch template for advanced configuration
  dynamic "launch_template" {
    for_each = lookup(each.value, "launch_template_id", null) != null ? [1] : []
    content {
      id      = lookup(each.value, "launch_template_id", null)
      version = lookup(each.value, "launch_template_version", "$Latest")
    }
  }

  # Remote access configuration
  dynamic "remote_access" {
    for_each = lookup(each.value, "enable_remote_access", false) ? [1] : []
    content {
      ec2_ssh_key               = lookup(each.value, "ec2_ssh_key", null)
      source_security_group_ids = lookup(each.value, "remote_access_sg_ids", [])
    }
  }

  tags = merge(
    local.common_tags,
    lookup(each.value, "tags", {}),
    # Karpenter discovery tags
    var.enable_karpenter ? {
      "karpenter.sh/discovery" = var.cluster_name
    } : {},
    # Cluster Autoscaler tags (if not using Karpenter)
    !var.enable_karpenter ? {
      "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
      "k8s.io/cluster-autoscaler/enabled"             = "true"
    } : {}
  )

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_policy,
  ]
}

################################################################################
# EKS Fargate Profiles
################################################################################

resource "aws_eks_fargate_profile" "this" {
  for_each = var.fargate_profiles

  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = "${var.cluster_name}-${each.key}"
  pod_execution_role_arn = aws_iam_role.fargate[0].arn
  subnet_ids             = lookup(each.value, "subnet_ids", var.subnet_ids)

  dynamic "selector" {
    for_each = lookup(each.value, "selectors", [])
    content {
      namespace = selector.value.namespace
      labels    = lookup(selector.value, "labels", {})
    }
  }

  tags = merge(
    local.common_tags,
    lookup(each.value, "tags", {})
  )

  depends_on = [
    aws_iam_role_policy_attachment.fargate_pod_execution_policy
  ]
}

# Fargate IAM Role
resource "aws_iam_role" "fargate" {
  count = length(var.fargate_profiles) > 0 ? 1 : 0

  name               = "${var.cluster_name}-fargate-role"
  assume_role_policy = data.aws_iam_policy_document.fargate_assume_role[0].json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "fargate_assume_role" {
  count = length(var.fargate_profiles) > 0 ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "fargate_pod_execution_policy" {
  count = length(var.fargate_profiles) > 0 ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate[0].name
}

################################################################################
# EKS Node IAM Role
################################################################################

resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# SSM permissions for node management
resource "aws_iam_role_policy_attachment" "node_ssm_policy" {
  count = var.enable_ssm_on_nodes ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.node.name
}

################################################################################
# EKS Add-ons (Managed Add-ons)
################################################################################

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  addon_version               = var.vpc_cni_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  service_account_role_arn    = var.enable_pod_identity ? null : aws_iam_role.vpc_cni[0].arn

  # Pod Identity association (if enabled)
  dynamic "pod_identity_association" {
    for_each = var.enable_pod_identity ? [1] : []
    content {
      service_account = "aws-node"
      role_arn        = aws_eks_pod_identity_association.vpc_cni[0].role_arn
    }
  }

  tags = local.common_tags

  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  addon_version               = var.coredns_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  configuration_values = var.coredns_configuration_values

  tags = local.common_tags

  depends_on = [aws_eks_node_group.this, aws_eks_fargate_profile.this]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  addon_version               = var.kube_proxy_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = local.common_tags

  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.ebs_csi_driver_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  service_account_role_arn    = var.enable_pod_identity ? null : aws_iam_role.ebs_csi[0].arn

  # Pod Identity association (if enabled)
  dynamic "pod_identity_association" {
    for_each = var.enable_pod_identity ? [1] : []
    content {
      service_account = "ebs-csi-controller-sa"
      role_arn        = aws_eks_pod_identity_association.ebs_csi[0].role_arn
    }
  }

  tags = local.common_tags

  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "efs_csi_driver" {
  count = var.enable_efs_csi_driver ? 1 : 0

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-efs-csi-driver"
  addon_version               = var.efs_csi_driver_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  service_account_role_arn    = var.enable_pod_identity ? null : aws_iam_role.efs_csi[0].arn

  # Pod Identity association (if enabled)
  dynamic "pod_identity_association" {
    for_each = var.enable_pod_identity ? [1] : []
    content {
      service_account = "efs-csi-controller-sa"
      role_arn        = aws_eks_pod_identity_association.efs_csi[0].role_arn
    }
  }

  tags = local.common_tags

  depends_on = [aws_eks_node_group.this]
}

# Amazon CloudWatch Observability Add-on
resource "aws_eks_addon" "cloudwatch_observability" {
  count = var.enable_cloudwatch_observability ? 1 : 0

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "amazon-cloudwatch-observability"
  addon_version               = var.cloudwatch_observability_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  service_account_role_arn    = var.enable_pod_identity ? null : aws_iam_role.cloudwatch_observability[0].arn

  tags = local.common_tags

  depends_on = [aws_eks_node_group.this]
}

# Amazon GuardDuty EKS Runtime Monitoring
resource "aws_eks_addon" "guardduty_agent" {
  count = var.enable_guardduty_agent ? 1 : 0

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-guardduty-agent"
  addon_version               = var.guardduty_agent_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = local.common_tags

  depends_on = [aws_eks_node_group.this]
}

# Pod Identity Agent (required for EKS Pod Identity)
resource "aws_eks_addon" "pod_identity_agent" {
  count = var.enable_pod_identity ? 1 : 0

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = var.pod_identity_agent_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = local.common_tags

  depends_on = [aws_eks_node_group.this]
}

################################################################################
# OIDC Provider for IRSA (Traditional method)
################################################################################

data "tls_certificate" "this" {
  count = var.enable_pod_identity ? 0 : 1
  url   = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  count = var.enable_pod_identity ? 0 : 1

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.this[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = local.common_tags
}

################################################################################
# EKS Pod Identity Associations (Modern method)
################################################################################

# VPC CNI Pod Identity
resource "aws_eks_pod_identity_association" "vpc_cni" {
  count = var.enable_pod_identity ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "aws-node"
  role_arn        = aws_iam_role.vpc_cni_pod_identity[0].arn

  tags = local.common_tags
}

# EBS CSI Driver Pod Identity
resource "aws_eks_pod_identity_association" "ebs_csi" {
  count = var.enable_pod_identity && var.enable_ebs_csi_driver ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi_pod_identity[0].arn

  tags = local.common_tags
}

# EFS CSI Driver Pod Identity
resource "aws_eks_pod_identity_association" "efs_csi" {
  count = var.enable_pod_identity && var.enable_efs_csi_driver ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "efs-csi-controller-sa"
  role_arn        = aws_iam_role.efs_csi_pod_identity[0].arn

  tags = local.common_tags
}

# CloudWatch Observability Pod Identity
resource "aws_eks_pod_identity_association" "cloudwatch_observability" {
  count = var.enable_pod_identity && var.enable_cloudwatch_observability ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  namespace       = "amazon-cloudwatch"
  service_account = "cloudwatch-agent"
  role_arn        = aws_iam_role.cloudwatch_observability_pod_identity[0].arn

  tags = local.common_tags
}

################################################################################
# IRSA IAM Roles (Traditional Method)
################################################################################

# VPC CNI IRSA
resource "aws_iam_role" "vpc_cni" {
  count = var.enable_pod_identity ? 0 : 1

  name               = "${var.cluster_name}-vpc-cni-irsa"
  assume_role_policy = data.aws_iam_policy_document.vpc_cni_assume[0].json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "vpc_cni_assume" {
  count = var.enable_pod_identity ? 0 : 1

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this[0].arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  count = var.enable_pod_identity ? 0 : 1

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni[0].name
}

# EBS CSI Driver IRSA
resource "aws_iam_role" "ebs_csi" {
  count = var.enable_pod_identity ? 0 : var.enable_ebs_csi_driver ? 1 : 0

  name               = "${var.cluster_name}-ebs-csi-irsa"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume[0].json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "ebs_csi_assume" {
  count = var.enable_pod_identity ? 0 : var.enable_ebs_csi_driver ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this[0].arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count = var.enable_pod_identity ? 0 : var.enable_ebs_csi_driver ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi[0].name
}

# EFS CSI Driver IRSA
resource "aws_iam_role" "efs_csi" {
  count = var.enable_pod_identity ? 0 : var.enable_efs_csi_driver ? 1 : 0

  name               = "${var.cluster_name}-efs-csi-irsa"
  assume_role_policy = data.aws_iam_policy_document.efs_csi_assume[0].json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "efs_csi_assume" {
  count = var.enable_pod_identity ? 0 : var.enable_efs_csi_driver ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this[0].arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:kube-system:efs-csi-controller-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "efs_csi" {
  count = var.enable_pod_identity ? 0 : var.enable_efs_csi_driver ? 1 : 0

  name        = "${var.cluster_name}-efs-csi-policy"
  description = "IAM policy for EFS CSI Driver"
  policy      = data.aws_iam_policy_document.efs_csi_policy[0].json

  tags = local.common_tags
}

data "aws_iam_policy_document" "efs_csi_policy" {
  count = var.enable_pod_identity ? 0 : var.enable_efs_csi_driver ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "elasticfilesystem:DescribeAccessPoints",
      "elasticfilesystem:DescribeFileSystems",
      "elasticfilesystem:DescribeMountTargets",
      "ec2:DescribeAvailabilityZones"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "elasticfilesystem:CreateAccessPoint"
    ]

    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/efs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "elasticfilesystem:DeleteAccessPoint"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/efs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "efs_csi" {
  count = var.enable_pod_identity ? 0 : var.enable_efs_csi_driver ? 1 : 0

  policy_arn = aws_iam_policy.efs_csi[0].arn
  role       = aws_iam_role.efs_csi[0].name
}

# CloudWatch Observability IRSA
resource "aws_iam_role" "cloudwatch_observability" {
  count = var.enable_pod_identity ? 0 : var.enable_cloudwatch_observability ? 1 : 0

  name               = "${var.cluster_name}-cloudwatch-observability-irsa"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_observability_assume[0].json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "cloudwatch_observability_assume" {
  count = var.enable_pod_identity ? 0 : var.enable_cloudwatch_observability ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this[0].arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "cloudwatch_observability_logs" {
  count = var.enable_pod_identity ? 0 : var.enable_cloudwatch_observability ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cloudwatch_observability[0].name
}

resource "aws_iam_role_policy_attachment" "cloudwatch_observability_xray" {
  count = var.enable_pod_identity ? 0 : var.enable_cloudwatch_observability ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  role       = aws_iam_role.cloudwatch_observability[0].name
}

################################################################################
# Pod Identity IAM Roles (Modern Method)
################################################################################

# VPC CNI Pod Identity Role
resource "aws_iam_role" "vpc_cni_pod_identity" {
  count = var.enable_pod_identity ? 1 : 0

  name               = "${var.cluster_name}-vpc-cni-pod-identity"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume[0].json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "pod_identity_assume" {
  count = var.enable_pod_identity ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role_policy_attachment" "vpc_cni_pod_identity" {
  count = var.enable_pod_identity ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni_pod_identity[0].name
}

# EBS CSI Driver Pod Identity Role
resource "aws_iam_role" "ebs_csi_pod_identity" {
  count = var.enable_pod_identity && var.enable_ebs_csi_driver ? 1 : 0

  name               = "${var.cluster_name}-ebs-csi-pod-identity"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume[0].json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_pod_identity" {
  count = var.enable_pod_identity && var.enable_ebs_csi_driver ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_pod_identity[0].name
}

# EFS CSI Driver Pod Identity Role
resource "aws_iam_role" "efs_csi_pod_identity" {
  count = var.enable_pod_identity && var.enable_efs_csi_driver ? 1 : 0

  name               = "${var.cluster_name}-efs-csi-pod-identity"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume[0].json
  tags               = local.common_tags
}

resource "aws_iam_policy" "efs_csi_pod_identity" {
  count = var.enable_pod_identity && var.enable_efs_csi_driver ? 1 : 0

  name        = "${var.cluster_name}-efs-csi-pod-identity-policy"
  description = "IAM policy for EFS CSI Driver with Pod Identity"
  policy      = data.aws_iam_policy_document.efs_csi_pod_identity_policy[0].json

  tags = local.common_tags
}

data "aws_iam_policy_document" "efs_csi_pod_identity_policy" {
  count = var.enable_pod_identity && var.enable_efs_csi_driver ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "elasticfilesystem:DescribeAccessPoints",
      "elasticfilesystem:DescribeFileSystems",
      "elasticfilesystem:DescribeMountTargets",
      "ec2:DescribeAvailabilityZones"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "elasticfilesystem:CreateAccessPoint"
    ]

    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/efs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "elasticfilesystem:DeleteAccessPoint"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/efs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "efs_csi_pod_identity" {
  count = var.enable_pod_identity && var.enable_efs_csi_driver ? 1 : 0

  policy_arn = aws_iam_policy.efs_csi_pod_identity[0].arn
  role       = aws_iam_role.efs_csi_pod_identity[0].name
}

# CloudWatch Observability Pod Identity Role
resource "aws_iam_role" "cloudwatch_observability_pod_identity" {
  count = var.enable_pod_identity && var.enable_cloudwatch_observability ? 1 : 0

  name               = "${var.cluster_name}-cloudwatch-observability-pod-identity"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume[0].json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_observability_pod_identity_logs" {
  count = var.enable_pod_identity && var.enable_cloudwatch_observability ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cloudwatch_observability_pod_identity[0].name
}

resource "aws_iam_role_policy_attachment" "cloudwatch_observability_pod_identity_xray" {
  count = var.enable_pod_identity && var.enable_cloudwatch_observability ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  role       = aws_iam_role.cloudwatch_observability_pod_identity[0].name
}

################################################################################
# Karpenter IRSA and IAM Roles
################################################################################

resource "aws_iam_role" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  name               = "${var.cluster_name}-karpenter-irsa"
  assume_role_policy = data.aws_iam_policy_document.karpenter_assume[0].json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "karpenter_assume" {
  count = var.enable_karpenter ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.enable_pod_identity ? "pods.eks.amazonaws.com" : aws_iam_openid_connect_provider.this[0].arn]
    }

    actions = [
      var.enable_pod_identity ? "sts:AssumeRole" : "sts:AssumeRoleWithWebIdentity",
      var.enable_pod_identity ? "sts:TagSession" : ""
    ]

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:sub"
        values   = ["system:serviceaccount:karpenter:karpenter"]
      }
    }

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_policy" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  name        = "${var.cluster_name}-karpenter-policy"
  description = "IAM policy for Karpenter"
  policy      = data.aws_iam_policy_document.karpenter_policy[0].json

  tags = local.common_tags
}

data "aws_iam_policy_document" "karpenter_policy" {
  count = var.enable_karpenter ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateTags",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
      "ec2:DeleteLaunchTemplate",
      "ec2:RunInstances",
      "ec2:TerminateInstances"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/karpenter.sh/discovery"
      values   = [var.cluster_name]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "ssm:GetParameter"
    ]

    resources = ["arn:aws:ssm:*:*:parameter/aws/service/*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "eks:DescribeCluster"
    ]

    resources = [aws_eks_cluster.this.arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [aws_iam_role.node.arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "pricing:GetProducts"
    ]

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "cluster_autoscaler_assume" {
  count = var.enable_cluster_autoscaler && !var.enable_karpenter ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.enable_pod_identity ? "pods.eks.amazonaws.com" : aws_iam_openid_connect_provider.this[0].arn]
    }

    actions = [
      var.enable_pod_identity ? "sts:AssumeRole" : "sts:AssumeRoleWithWebIdentity",
      var.enable_pod_identity ? "sts:TagSession" : ""
    ]

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:sub"
        values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
      }
    }

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_policy" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler && !var.enable_karpenter ? 1 : 0

  name        = "${var.cluster_name}-cluster-autoscaler-policy"
  description = "IAM policy for Cluster Autoscaler"
  policy      = data.aws_iam_policy_document.cluster_autoscaler_policy[0].json

  tags = local.common_tags
}

data "aws_iam_policy_document" "cluster_autoscaler_policy" {
  count = var.enable_cluster_autoscaler && !var.enable_karpenter ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeImages",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}"
      values   = ["owned"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler && !var.enable_karpenter ? 1 : 0

  policy_arn = aws_iam_policy.cluster_autoscaler[0].arn
  role       = aws_iam_role.cluster_autoscaler[0].name
}

################################################################################
# IRSA for Cert-Manager
################################################################################

resource "aws_iam_role" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  name               = "${var.cluster_name}-cert-manager-irsa"
  assume_role_policy = data.aws_iam_policy_document.cert_manager_assume[0].json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "cert_manager_assume" {
  count = var.enable_cert_manager ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.enable_pod_identity ? "pods.eks.amazonaws.com" : aws_iam_openid_connect_provider.this[0].arn]
    }

    actions = [
      var.enable_pod_identity ? "sts:AssumeRole" : "sts:AssumeRoleWithWebIdentity",
      var.enable_pod_identity ? "sts:TagSession" : ""
    ]

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:sub"
        values   = ["system:serviceaccount:cert-manager:cert-manager"]
      }
    }

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_policy" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  name        = "${var.cluster_name}-cert-manager-policy"
  description = "IAM policy for Cert-Manager Route53 DNS validation"
  policy      = data.aws_iam_policy_document.cert_manager_policy[0].json

  tags = local.common_tags
}

data "aws_iam_policy_document" "cert_manager_policy" {
  count = var.enable_cert_manager ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "route53:GetChange"
    ]

    resources = ["arn:aws:route53:::change/*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets"
    ]

    resources = var.cert_manager_route53_zone_arns
  }

  statement {
    effect = "Allow"

    actions = [
      "route53:ListHostedZonesByName",
      "route53:ListHostedZones"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  policy_arn = aws_iam_policy.cert_manager[0].arn
  role       = aws_iam_role.cert_manager[0].name
}

################################################################################
# IRSA for AWS Load Balancer Controller
################################################################################

resource "aws_iam_role" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name               = "${var.cluster_name}-aws-load-balancer-controller-irsa"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume[0].json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "aws_load_balancer_controller_assume" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.enable_pod_identity ? "pods.eks.amazonaws.com" : aws_iam_openid_connect_provider.this[0].arn]
    }

    actions = [
      var.enable_pod_identity ? "sts:AssumeRole" : "sts:AssumeRoleWithWebIdentity",
      var.enable_pod_identity ? "sts:TagSession" : ""
    ]

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:sub"
        values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
      }
    }

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name        = "${var.cluster_name}-aws-load-balancer-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = var.aws_load_balancer_controller_policy_json != null ? var.aws_load_balancer_controller_policy_json : file("${path.module}/policies/aws-load-balancer-controller-policy.json")

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  policy_arn = aws_iam_policy.aws_load_balancer_controller[0].arn
  role       = aws_iam_role.aws_load_balancer_controller[0].name
}

################################################################################
# CloudWatch Log Group for EKS
################################################################################

resource "aws_cloudwatch_log_group" "this" {
  count = length(var.cluster_log_types) > 0 ? 1 : 0

  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = local.common_tags
}

################################################################################
# Security Group Rules for Node-to-Node Communication
################################################################################

resource "aws_security_group_rule" "node_to_node" {
  count = var.create_node_security_group_rules ? 1 : 0

  description              = "Allow nodes to communicate with each other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

resource "aws_security_group_rule" "node_to_cluster_api" {
  count = var.create_node_security_group_rules ? 1 : 0

  description              = "Allow nodes to communicate with the cluster API server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

data "aws_iam_policy_document" "cluster_autoscaler_assume" {
  count = var.enable_cluster_autoscaler && !var.enable_karpenter ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.enable_pod_identity ? "pods.eks.amazonaws.com" : aws_iam_openid_connect_provider.this[0].arn]
    }

    actions = [
      var.enable_pod_identity ? "sts:AssumeRole" : "sts:AssumeRoleWithWebIdentity",
      var.enable_pod_identity ? "sts:TagSession" : ""
    ]

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:sub"
        values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
      }
    }

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_policy" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler && !var.enable_karpenter ? 1 : 0

  name        = "${var.cluster_name}-cluster-autoscaler-policy"
  description = "IAM policy for Cluster Autoscaler"
  policy      = data.aws_iam_policy_document.cluster_autoscaler_policy[0].json

  tags = local.common_tags
}

data "aws_iam_policy_document" "cluster_autoscaler_policy" {
  count = var.enable_cluster_autoscaler && !var.enable_karpenter ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeImages",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}"
      values   = ["owned"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler && !var.enable_karpenter ? 1 : 0

  policy_arn = aws_iam_policy.cluster_autoscaler[0].arn
  role       = aws_iam_role.cluster_autoscaler[0].name
}

# Cluster Autoscaler Pod Identity Association (if using Pod Identity)
resource "aws_eks_pod_identity_association" "cluster_autoscaler" {
  count = var.enable_pod_identity && var.enable_cluster_autoscaler && !var.enable_karpenter ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "cluster-autoscaler"
  role_arn        = aws_iam_role.cluster_autoscaler[0].arn

  tags = local.common_tags
}

################################################################################
# Cert-Manager IRSA
################################################################################

resource "aws_iam_role" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  name               = "${var.cluster_name}-cert-manager-irsa"
  assume_role_policy = data.aws_iam_policy_document.cert_manager_assume[0].json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "cert_manager_assume" {
  count = var.enable_cert_manager ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.enable_pod_identity ? "pods.eks.amazonaws.com" : aws_iam_openid_connect_provider.this[0].arn]
    }

    actions = [
      var.enable_pod_identity ? "sts:AssumeRole" : "sts:AssumeRoleWithWebIdentity",
      var.enable_pod_identity ? "sts:TagSession" : ""
    ]

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:sub"
        values   = ["system:serviceaccount:cert-manager:cert-manager"]
      }
    }

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_policy" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  name        = "${var.cluster_name}-cert-manager-policy"
  description = "IAM policy for Cert-Manager Route53 DNS validation"
  policy      = data.aws_iam_policy_document.cert_manager_policy[0].json

  tags = local.common_tags
}

data "aws_iam_policy_document" "cert_manager_policy" {
  count = var.enable_cert_manager ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "route53:GetChange"
    ]

    resources = ["arn:aws:route53:::change/*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets"
    ]

    resources = var.cert_manager_route53_zone_arns
  }

  statement {
    effect = "Allow"

    actions = [
      "route53:ListHostedZonesByName",
      "route53:ListHostedZones"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  policy_arn = aws_iam_policy.cert_manager[0].arn
  role       = aws_iam_role.cert_manager[0].name
}

# Cert-Manager Pod Identity Association (if using Pod Identity)
resource "aws_eks_pod_identity_association" "cert_manager" {
  count = var.enable_pod_identity && var.enable_cert_manager ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  namespace       = "cert-manager"
  service_account = "cert-manager"
  role_arn        = aws_iam_role.cert_manager[0].arn

  tags = local.common_tags
}

################################################################################
# AWS Load Balancer Controller IRSA
################################################################################

resource "aws_iam_role" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name               = "${var.cluster_name}-aws-load-balancer-controller-irsa"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume[0].json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "aws_load_balancer_controller_assume" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.enable_pod_identity ? "pods.eks.amazonaws.com" : aws_iam_openid_connect_provider.this[0].arn]
    }

    actions = [
      var.enable_pod_identity ? "sts:AssumeRole" : "sts:AssumeRoleWithWebIdentity",
      var.enable_pod_identity ? "sts:TagSession" : ""
    ]

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:sub"
        values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
      }
    }

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name        = "${var.cluster_name}-aws-load-balancer-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = var.aws_load_balancer_controller_policy_json != null ? var.aws_load_balancer_controller_policy_json : file("${path.module}/policies/aws-load-balancer-controller-policy.json")

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  policy_arn = aws_iam_policy.aws_load_balancer_controller[0].arn
  role       = aws_iam_role.aws_load_balancer_controller[0].name
}

# AWS Load Balancer Controller Pod Identity Association (if using Pod Identity)
resource "aws_eks_pod_identity_association" "aws_load_balancer_controller" {
  count = var.enable_pod_identity && var.enable_aws_load_balancer_controller ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.aws_load_balancer_controller[0].arn

  tags = local.common_tags
}

################################################################################
# CloudWatch Log Group for EKS Control Plane Logs
################################################################################

resource "aws_cloudwatch_log_group" "this" {
  count = length(var.cluster_log_types) > 0 ? 1 : 0

  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = local.common_tags
}

data "aws_iam_policy_document" "cluster_autoscaler_assume" {
  count = var.enable_cluster_autoscaler && !var.enable_karpenter ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.enable_pod_identity ? "pods.eks.amazonaws.com" : aws_iam_openid_connect_provider.this[0].arn]
    }

    actions = [
      var.enable_pod_identity ? "sts:AssumeRole" : "sts:AssumeRoleWithWebIdentity",
      var.enable_pod_identity ? "sts:TagSession" : ""
    ]

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:sub"
        values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
      }
    }

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_policy" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler && !var.enable_karpenter ? 1 : 0

  name        = "${var.cluster_name}-cluster-autoscaler-policy"
  description = "IAM policy for Cluster Autoscaler"
  policy      = data.aws_iam_policy_document.cluster_autoscaler_policy[0].json

  tags = local.common_tags
}

data "aws_iam_policy_document" "cluster_autoscaler_policy" {
  count = var.enable_cluster_autoscaler && !var.enable_karpenter ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeImages",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}"
      values   = ["owned"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler && !var.enable_karpenter ? 1 : 0

  policy_arn = aws_iam_policy.cluster_autoscaler[0].arn
  role       = aws_iam_role.cluster_autoscaler[0].name
}

################################################################################
# Cert-Manager IRSA
################################################################################

resource "aws_iam_role" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  name               = "${var.cluster_name}-cert-manager-irsa"
  assume_role_policy = data.aws_iam_policy_document.cert_manager_assume[0].json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "cert_manager_assume" {
  count = var.enable_cert_manager ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.enable_pod_identity ? "pods.eks.amazonaws.com" : aws_iam_openid_connect_provider.this[0].arn]
    }

    actions = [
      var.enable_pod_identity ? "sts:AssumeRole" : "sts:AssumeRoleWithWebIdentity",
      var.enable_pod_identity ? "sts:TagSession" : ""
    ]

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:sub"
        values   = ["system:serviceaccount:cert-manager:cert-manager"]
      }
    }

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_policy" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  name        = "${var.cluster_name}-cert-manager-policy"
  description = "IAM policy for Cert-Manager Route53 DNS validation"
  policy      = data.aws_iam_policy_document.cert_manager_policy[0].json

  tags = local.common_tags
}

data "aws_iam_policy_document" "cert_manager_policy" {
  count = var.enable_cert_manager ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "route53:GetChange"
    ]

    resources = ["arn:aws:route53:::change/*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets"
    ]

    resources = var.cert_manager_route53_zone_arns
  }

  statement {
    effect = "Allow"

    actions = [
      "route53:ListHostedZonesByName",
      "route53:ListHostedZones"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  policy_arn = aws_iam_policy.cert_manager[0].arn
  role       = aws_iam_role.cert_manager[0].name
}

################################################################################
# AWS Load Balancer Controller IRSA
################################################################################

resource "aws_iam_role" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name               = "${var.cluster_name}-aws-load-balancer-controller-irsa"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume[0].json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "aws_load_balancer_controller_assume" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.enable_pod_identity ? "pods.eks.amazonaws.com" : aws_iam_openid_connect_provider.this[0].arn]
    }

    actions = [
      var.enable_pod_identity ? "sts:AssumeRole" : "sts:AssumeRoleWithWebIdentity",
      var.enable_pod_identity ? "sts:TagSession" : ""
    ]

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:sub"
        values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
      }
    }

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name        = "${var.cluster_name}-aws-load-balancer-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = var.aws_load_balancer_controller_policy_json != null ? var.aws_load_balancer_controller_policy_json : file("${path.module}/policies/aws-load-balancer-controller-policy.json")

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  policy_arn = aws_iam_policy.aws_load_balancer_controller[0].arn
  role       = aws_iam_role.aws_load_balancer_controller[0].name
}

################################################################################
# CloudWatch Log Group for EKS Control Plane Logs
################################################################################

resource "aws_cloudwatch_log_group" "this" {
  count = length(var.cluster_log_types) > 0 ? 1 : 0

  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = local.common_tags
}

################################################################################
# Security Group Rules for Cluster
################################################################################

resource "aws_security_group_rule" "cluster_ingress_workstation_https" {
  count = var.enable_workstation_access && length(var.workstation_cidr_blocks) > 0 ? 1 : 0

  description       = "Allow workstation to communicate with the cluster API Server"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.workstation_cidr_blocks
  security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

data "aws_iam_policy_document" "cluster_autoscaler_assume" {
  count = var.enable_cluster_autoscaler && !var.enable_karpenter ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.enable_pod_identity ? "pods.eks.amazonaws.com" : aws_iam_openid_connect_provider.this[0].arn]
    }

    actions = [
      var.enable_pod_identity ? "sts:AssumeRole" : "sts:AssumeRoleWithWebIdentity",
      var.enable_pod_identity ? "sts:TagSession" : ""
    ]

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:sub"
        values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
      }
    }

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_policy" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler && !var.enable_karpenter ? 1 : 0

  name        = "${var.cluster_name}-cluster-autoscaler-policy"
  description = "IAM policy for Cluster Autoscaler"
  policy      = data.aws_iam_policy_document.cluster_autoscaler_policy[0].json

  tags = local.common_tags
}

data "aws_iam_policy_document" "cluster_autoscaler_policy" {
  count = var.enable_cluster_autoscaler && !var.enable_karpenter ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeImages",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}"
      values   = ["owned"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler && !var.enable_karpenter ? 1 : 0

  policy_arn = aws_iam_policy.cluster_autoscaler[0].arn
  role       = aws_iam_role.cluster_autoscaler[0].name
}

################################################################################
# AWS Load Balancer Controller IRSA
################################################################################

resource "aws_iam_role" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name               = "${var.cluster_name}-aws-load-balancer-controller-irsa"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume[0].json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "aws_load_balancer_controller_assume" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.enable_pod_identity ? "pods.eks.amazonaws.com" : aws_iam_openid_connect_provider.this[0].arn]
    }

    actions = [
      var.enable_pod_identity ? "sts:AssumeRole" : "sts:AssumeRoleWithWebIdentity",
      var.enable_pod_identity ? "sts:TagSession" : ""
    ]

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:sub"
        values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
      }
    }

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name        = "${var.cluster_name}-aws-load-balancer-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = var.aws_load_balancer_controller_policy_json != null ? var.aws_load_balancer_controller_policy_json : file("${path.module}/policies/aws-load-balancer-controller-policy.json")

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  policy_arn = aws_iam_policy.aws_load_balancer_controller[0].arn
  role       = aws_iam_role.aws_load_balancer_controller[0].name
}

# AWS Load Balancer Controller Pod Identity Association
resource "aws_eks_pod_identity_association" "aws_load_balancer_controller" {
  count = var.enable_pod_identity && var.enable_aws_load_balancer_controller ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.aws_load_balancer_controller[0].arn

  tags = local.common_tags
}

################################################################################
# External DNS IRSA (Optional)
################################################################################

resource "aws_iam_role" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name               = "${var.cluster_name}-external-dns-irsa"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume[0].json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "external_dns_assume" {
  count = var.enable_external_dns ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.enable_pod_identity ? "pods.eks.amazonaws.com" : aws_iam_openid_connect_provider.this[0].arn]
    }

    actions = [
      var.enable_pod_identity ? "sts:AssumeRole" : "sts:AssumeRoleWithWebIdentity",
      var.enable_pod_identity ? "sts:TagSession" : ""
    ]

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:sub"
        values   = ["system:serviceaccount:kube-system:external-dns"]
      }
    }

    dynamic "condition" {
      for_each = var.enable_pod_identity ? [] : [1]
      content {
        test     = "StringEquals"
        variable = "${local.oidc_issuer}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_policy" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name        = "${var.cluster_name}-external-dns-policy"
  description = "IAM policy for External DNS"
  policy      = data.aws_iam_policy_document.external_dns_policy[0].json

  tags = local.common_tags
}

data "aws_iam_policy_document" "external_dns_policy" {
  count = var.enable_external_dns ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets"
    ]

    resources = var.external_dns_route53_zone_arns
  }

  statement {
    effect = "Allow"

    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  policy_arn = aws_iam_policy.external_dns[0].arn
  role       = aws_iam_role.external_dns[0].name
}

# External DNS Pod Identity Association
resource "aws_eks_pod_identity_association" "external_dns" {
  count = var.enable_pod_identity && var.enable_external_dns ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "external-dns"
  role_arn        = aws_iam_role.external_dns[0].arn

  tags = local.common_tags
}

################################################################################
# CloudWatch Log Group for EKS Control Plane Logs
################################################################################

resource "aws_cloudwatch_log_group" "this" {
  count = length(var.cluster_log_types) > 0 ? 1 : 0

  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = local.common_tags
}

################################################################################
# Security Group Rules for Node-to-Node Communication
################################################################################

resource "aws_security_group_rule" "node_to_node" {
  count = var.create_node_security_group_rules ? 1 : 0

  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description              = "Allow nodes to communicate with each other"
}
