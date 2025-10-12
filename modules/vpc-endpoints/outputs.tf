################################################################################
# VPC Endpoints Module - Outputs
################################################################################

# Security Group Outputs
################################################################################

output "security_group_id" {
  description = "ID of the VPC endpoints security group"
  value       = try(aws_security_group.vpc_endpoints[0].id, null)
}

output "security_group_arn" {
  description = "ARN of the VPC endpoints security group"
  value       = try(aws_security_group.vpc_endpoints[0].arn, null)
}

output "security_group_name" {
  description = "Name of the VPC endpoints security group"
  value       = try(aws_security_group.vpc_endpoints[0].name, null)
}

################################################################################
# Interface Endpoint Outputs
################################################################################

output "interface_endpoints" {
  description = "Map of interface VPC endpoint IDs"
  value = {
    for k, v in aws_vpc_endpoint.interface : k => v.id
  }
}

output "interface_endpoint_arns" {
  description = "Map of interface VPC endpoint ARNs"
  value = {
    for k, v in aws_vpc_endpoint.interface : k => v.arn
  }
}

output "interface_endpoint_dns_entries" {
  description = "Map of interface VPC endpoint DNS entries"
  value = {
    for k, v in aws_vpc_endpoint.interface : k => v.dns_entry
  }
}

output "interface_endpoint_network_interface_ids" {
  description = "Map of interface VPC endpoint network interface IDs"
  value = {
    for k, v in aws_vpc_endpoint.interface : k => v.network_interface_ids
  }
}

output "interface_endpoint_state" {
  description = "Map of interface VPC endpoint states"
  value = {
    for k, v in aws_vpc_endpoint.interface : k => v.state
  }
}

################################################################################
# Gateway Endpoint Outputs
################################################################################

output "gateway_endpoints" {
  description = "Map of gateway VPC endpoint IDs"
  value = {
    for k, v in aws_vpc_endpoint.gateway : k => v.id
  }
}

output "gateway_endpoint_arns" {
  description = "Map of gateway VPC endpoint ARNs"
  value = {
    for k, v in aws_vpc_endpoint.gateway : k => v.arn
  }
}

output "gateway_endpoint_state" {
  description = "Map of gateway VPC endpoint states"
  value = {
    for k, v in aws_vpc_endpoint.gateway : k => v.state
  }
}

output "gateway_endpoint_prefix_list_ids" {
  description = "Map of gateway VPC endpoint prefix list IDs"
  value = {
    for k, v in aws_vpc_endpoint.gateway : k => v.prefix_list_id
  }
}

################################################################################
# Combined Outputs
################################################################################

output "all_endpoints" {
  description = "Map of all VPC endpoint IDs (interface and gateway)"
  value = merge(
    { for k, v in aws_vpc_endpoint.interface : k => v.id },
    { for k, v in aws_vpc_endpoint.gateway : k => v.id }
  )
}

output "all_endpoint_arns" {
  description = "Map of all VPC endpoint ARNs (interface and gateway)"
  value = merge(
    { for k, v in aws_vpc_endpoint.interface : k => v.arn },
    { for k, v in aws_vpc_endpoint.gateway : k => v.arn }
  )
}

output "endpoint_count" {
  description = "Total number of VPC endpoints created"
  value = {
    interface = length(aws_vpc_endpoint.interface)
    gateway   = length(aws_vpc_endpoint.gateway)
    total     = length(aws_vpc_endpoint.interface) + length(aws_vpc_endpoint.gateway)
  }
}
