################################################################################
# QA Environment - Terraform Configuration
# Production-like Setup for Quality Assurance Testing
################################################################################

# Project Configuration
project_name = "myapp"
environment  = "qa"
aws_region   = "us-east-1"

################################################################################
# VPC Configuration
################################################################################

vpc_cidr           = "10.1.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Subnet CIDR Blocks
public_subnet_cidrs = [
  "10.1.1.0/24",  # us-east-1a
  "10.1.2.0/24",  # us-east-1b
  "10.1.3.0/24",  # us-east-1c
]

private_subnet_cidrs = [
  "10.1.11.0/24", # us-east-1a
  "10.1.12.0/24", # us-east-1b
  "10.1.13.0/24", # us-east-1c
]

database_subnet_cidrs = [
  "10.1.21.0/24", # us-east-1a
  "10.1.22.0/24", # us-east-1b
  "10.1.23.0/24", # us-east-1c
]

################################################################################
# NAT Gateway Configuration (Balanced)
################################################################################

enable_nat_gateway     = true
single_nat_gateway     = false # Multiple NAT for better availability
one_nat_gateway_per_az = true  # One NAT per AZ

################################################################################
# VPC Features
################################################################################

enable_flow_logs         = true
flow_logs_retention_days = 30   # Standard retention for QA
enable_vpc_endpoints     = true  # Enable for testing

################################################################################
# Common Tags
################################################################################

common_tags = {
  Environment     = "qa"
  Project         = "myapp"
  ManagedBy       = "Terraform"
  CostCenter      = "engineering"
  Owner           = "qa-team"
  Backup          = "daily"
  DataClass       = "internal"
  TestingPhase    = "integration"
}
