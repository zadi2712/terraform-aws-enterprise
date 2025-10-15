################################################################################
# VPC Endpoints Module - Main Configuration
# Purpose: Create Interface and Gateway VPC endpoints for AWS services
# Well-Architected Pillars: Security, Cost Optimization, Performance
################################################################################

locals {
  # Filter interface endpoints (exclude gateway endpoints)
  interface_endpoints = {
    for k, v in var.endpoints : k => v
    if lookup(v, "service_type", "Interface") == "Interface"
  }

  # Create security group for interface endpoints if not provided
  create_security_group = var.create_security_group && length(local.interface_endpoints) > 0

  # Common tags
  common_tags = merge(
    var.tags,
    {
      ManagedBy = "Terraform"
      Module    = "vpc-endpoints"
    }
  )
}

################################################################################
# Data Sources
################################################################################

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

################################################################################
# Security Group for VPC Endpoints
################################################################################

resource "aws_security_group" "vpc_endpoints" {
  count = local.create_security_group ? 1 : 0

  name_prefix = "${var.name_prefix}-vpce-"
  description = "Security group for VPC endpoints"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-vpc-endpoints-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Ingress rule - Allow HTTPS from VPC CIDR
resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_https" {
  count = local.create_security_group ? 1 : 0

  security_group_id = aws_security_group.vpc_endpoints[0].id
  description       = "Allow HTTPS inbound from VPC"

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = var.vpc_cidr

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-vpce-https-ingress"
    }
  )
}

# Egress rule - Allow all outbound (required for endpoint functionality)
resource "aws_vpc_security_group_egress_rule" "vpc_endpoints_all" {
  count = local.create_security_group ? 1 : 0

  security_group_id = aws_security_group.vpc_endpoints[0].id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-vpce-all-egress"
    }
  )
}

################################################################################
# Interface VPC Endpoints
################################################################################

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.${each.value.service}"
  vpc_endpoint_type = "Interface"

  # Private DNS configuration
  private_dns_enabled = lookup(each.value, "private_dns_enabled", true)

  # Subnet configuration
  subnet_ids = lookup(each.value, "subnet_ids", var.private_subnet_ids)

  # Security group configuration
  security_group_ids = lookup(
    each.value,
    "security_group_ids",
    local.create_security_group ? [aws_security_group.vpc_endpoints[0].id] : var.security_group_ids
  )

  # Optional policy
  policy = lookup(each.value, "policy", null)

  # Auto-accept - useful for cross-account endpoints
  auto_accept = lookup(each.value, "auto_accept", null)

  tags = merge(
    local.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name    = "${var.name_prefix}-${each.key}-vpce"
      Service = each.value.service
      Type    = "Interface"
    }
  )

  # Timeouts
  timeouts {
    create = lookup(each.value, "timeout_create", "10m")
    update = lookup(each.value, "timeout_update", "10m")
    delete = lookup(each.value, "timeout_delete", "10m")
  }

  lifecycle {
    create_before_destroy = false
  }
}

################################################################################
# Gateway VPC Endpoints
################################################################################

resource "aws_vpc_endpoint" "gateway" {
  for_each = {
    for k, v in var.endpoints : k => v
    if lookup(v, "service_type", "Interface") == "Gateway"
  }

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.${each.value.service}"
  vpc_endpoint_type = "Gateway"

  # Route table associations for gateway endpoints
  route_table_ids = lookup(each.value, "route_table_ids", var.route_table_ids)

  # Optional policy
  policy = lookup(each.value, "policy", null)

  # Auto-accept
  auto_accept = lookup(each.value, "auto_accept", null)

  tags = merge(
    local.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name    = "${var.name_prefix}-${each.key}-vpce"
      Service = each.value.service
      Type    = "Gateway"
    }
  )

  # Timeouts
  timeouts {
    create = lookup(each.value, "timeout_create", "10m")
    update = lookup(each.value, "timeout_update", "10m")
    delete = lookup(each.value, "timeout_delete", "10m")
  }

  lifecycle {
    create_before_destroy = false
  }
}
