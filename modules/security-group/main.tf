################################################################################
# Security Group Module - Main Configuration
################################################################################

resource "aws_security_group" "this" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

################################################################################
# Ingress Rules
################################################################################

resource "aws_security_group_rule" "ingress" {
  for_each = { for idx, rule in var.ingress_rules : idx => rule }

  type              = "ingress"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = lookup(each.value, "cidr_blocks", null)
  ipv6_cidr_blocks  = lookup(each.value, "ipv6_cidr_blocks", null)
  source_security_group_id = lookup(each.value, "source_security_group_id", null)
  description       = lookup(each.value, "description", "Managed by Terraform")
  security_group_id = aws_security_group.this.id
}

################################################################################
# Egress Rules
################################################################################

resource "aws_security_group_rule" "egress" {
  for_each = { for idx, rule in var.egress_rules : idx => rule }

  type              = "egress"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = lookup(each.value, "cidr_blocks", null)
  ipv6_cidr_blocks  = lookup(each.value, "ipv6_cidr_blocks", null)
  destination_security_group_id = lookup(each.value, "destination_security_group_id", null)
  description       = lookup(each.value, "description", "Managed by Terraform")
  security_group_id = aws_security_group.this.id
}
