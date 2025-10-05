################################################################################
# Networking Layer - Outputs
################################################################################

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = module.vpc.vpc_arn
}

# Subnet Outputs
output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "List of database subnet IDs"
  value       = module.vpc.database_subnet_ids
}

output "database_subnet_group_name" {
  description = "Name of the database subnet group"
  value       = module.vpc.database_subnet_group_name
}

# Gateway Outputs
output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.nat_gateway_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.internet_gateway_id
}

# Route Table Outputs
output "public_route_table_ids" {
  description = "List of public route table IDs"
  value       = module.vpc.public_route_table_ids
}

output "private_route_table_ids" {
  description = "List of private route table IDs"
  value       = module.vpc.private_route_table_ids
}

# VPC Endpoint Outputs
output "vpc_endpoint_s3_id" {
  description = "ID of the S3 VPC endpoint"
  value       = module.vpc.vpc_endpoint_s3_id
}

output "vpc_endpoint_dynamodb_id" {
  description = "ID of the DynamoDB VPC endpoint"
  value       = module.vpc.vpc_endpoint_dynamodb_id
}

# Flow Logs Output
output "vpc_flow_log_id" {
  description = "ID of the VPC Flow Log"
  value       = module.vpc.vpc_flow_log_id
}

output "vpc_flow_log_cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group for VPC Flow Logs"
  value       = module.vpc.vpc_flow_log_cloudwatch_log_group_name
}

# Availability Zones
output "availability_zones" {
  description = "List of availability zones used"
  value       = var.availability_zones
}

# Network Summary for Other Layers
output "network_summary" {
  description = "Summary of network configuration for use by other layers"
  value = {
    vpc_id                = module.vpc.vpc_id
    vpc_cidr              = module.vpc.vpc_cidr
    public_subnet_ids     = module.vpc.public_subnet_ids
    private_subnet_ids    = module.vpc.private_subnet_ids
    database_subnet_ids   = module.vpc.database_subnet_ids
    availability_zones    = var.availability_zones
    environment           = var.environment
  }
}
