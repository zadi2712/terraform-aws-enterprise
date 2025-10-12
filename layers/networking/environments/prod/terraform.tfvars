################################################################################
# Production Environment - Terraform Configuration
# High-Availability, Secure Setup for Production Workloads
################################################################################

# Project Configuration
project_name = "myapp"
environment  = "prod"
aws_region   = "us-east-1"

################################################################################
# VPC Configuration
################################################################################

vpc_cidr           = "10.10.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Subnet CIDR Blocks
public_subnet_cidrs = [
  "10.10.1.0/24",  # us-east-1a
  "10.10.2.0/24",  # us-east-1b
  "10.10.3.0/24",  # us-east-1c
]

private_subnet_cidrs = [
  "10.10.11.0/24", # us-east-1a
  "10.10.12.0/24", # us-east-1b
  "10.10.13.0/24", # us-east-1c
]

database_subnet_cidrs = [
  "10.10.21.0/24", # us-east-1a
  "10.10.22.0/24", # us-east-1b
  "10.10.23.0/24", # us-east-1c
]

################################################################################
# NAT Gateway Configuration (High Availability)
################################################################################

enable_nat_gateway     = true
single_nat_gateway     = false # Multiple NAT Gateways required
one_nat_gateway_per_az = true  # One NAT Gateway per AZ for maximum resilience

################################################################################
# VPC Features
################################################################################

enable_flow_logs         = true
flow_logs_retention_days = 90   # Extended retention for compliance
enable_vpc_endpoints     = true  # Enabled for security and performance

################################################################################
# Common Tags
################################################################################

common_tags = {
  Environment     = "prod"
  Project         = "myapp"
  ManagedBy       = "Terraform"
  CostCenter      = "operations"
  Owner           = "platform-team"
  Backup          = "continuous"
  DataClass       = "confidential"
  Compliance      = "SOC2,PCI-DSS"
  BusinessUnit    = "product"
  Criticality     = "high"
  DisasterRecovery = "enabled"
}
