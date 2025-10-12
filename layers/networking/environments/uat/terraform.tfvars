################################################################################
# UAT Environment - Terraform Configuration
# Production-Mirrored Setup for User Acceptance Testing
################################################################################

# Project Configuration
project_name = "myapp"
environment  = "uat"
aws_region   = "us-east-1"

################################################################################
# VPC Configuration
################################################################################

vpc_cidr           = "10.2.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Subnet CIDR Blocks
public_subnet_cidrs = [
  "10.2.1.0/24",  # us-east-1a
  "10.2.2.0/24",  # us-east-1b
  "10.2.3.0/24",  # us-east-1c
]

private_subnet_cidrs = [
  "10.2.11.0/24", # us-east-1a
  "10.2.12.0/24", # us-east-1b
  "10.2.13.0/24", # us-east-1c
]

database_subnet_cidrs = [
  "10.2.21.0/24", # us-east-1a
  "10.2.22.0/24", # us-east-1b
  "10.2.23.0/24", # us-east-1c
]

################################################################################
# NAT Gateway Configuration (Production-like)
################################################################################

enable_nat_gateway     = true
single_nat_gateway     = false # Multiple NAT for high availability
one_nat_gateway_per_az = true  # One NAT per AZ for redundancy

################################################################################
# VPC Features
################################################################################

enable_flow_logs         = true
flow_logs_retention_days = 60   # Extended retention for UAT
enable_vpc_endpoints     = true  # Enable for production-like testing

################################################################################
# Common Tags
################################################################################

common_tags = {
  Environment     = "uat"
  Project         = "myapp"
  ManagedBy       = "Terraform"
  CostCenter      = "engineering"
  Owner           = "uat-team"
  Backup          = "daily"
  DataClass       = "confidential"
  TestingPhase    = "user-acceptance"
  BusinessUnit    = "product"
}
