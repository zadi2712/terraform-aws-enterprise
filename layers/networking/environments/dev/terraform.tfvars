################################################################################
# Networking Layer - DEV Environment Configuration
################################################################################

# General Configuration
environment  = "dev"
aws_region   = "us-east-1"
project_name = "enterprise"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"

# Availability Zones
availability_zones = ["us-east-1a", "us-east-1b"]

# Subnet Configuration
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
database_subnet_cidrs = ["10.0.21.0/24", "10.0.22.0/24"]

# NAT Gateway Configuration (cost optimization for dev)
enable_nat_gateway     = true
single_nat_gateway     = true  # Single NAT for dev to save costs
one_nat_gateway_per_az = false

# VPC Features
enable_flow_logs           = true
flow_logs_retention_days   = 7
enable_vpc_endpoints       = true

# Common Tags
common_tags = {
  Environment = "dev"
  Project     = "enterprise-infrastructure"
  ManagedBy   = "terraform"
  Layer       = "networking"
  CostCenter  = "engineering"
  Owner       = "platform-team"
}
