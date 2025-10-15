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
  "10.1.1.0/24", # us-east-1a
  "10.1.2.0/24", # us-east-1b
  "10.1.3.0/24", # us-east-1c
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
one_nat_gateway_per_az = true  # One NAT per AZ (3 NAT Gateways)

################################################################################
# VPC Features
################################################################################

enable_flow_logs         = true
flow_logs_retention_days = 30 # Standard retention for QA

################################################################################
# VPC Endpoints Configuration
################################################################################

# Enable VPC endpoints for AWS services (production-like testing)
enable_vpc_endpoints = true

# When enabled, the following 20 VPC endpoints are created automatically:
#
# INTERFACE ENDPOINTS (18 total - deployed across 3 AZs):
# --------------------------------------------------------
# Compute & Container Services:
#   - ec2, ecr.api, ecr.dkr, ecs, ecs-telemetry
#   - lambda, autoscaling
#
# Security & Identity:
#   - kms, secretsmanager, sts
#
# Monitoring & Logging:
#   - logs, monitoring, events
#
# Database & Storage:
#   - rds, elasticache
#
# Messaging & Integration:
#   - sns, sqs
#
# Systems Management:
#   - ssm
#
# Load Balancing:
#   - elasticloadbalancing
#
# GATEWAY ENDPOINTS (2 total - FREE):
# -----------------------------------
#   - s3, dynamodb (both FREE)
#
# COST ESTIMATE (QA - 3 AZs):
# ----------------------------
# Interface Endpoints: 18 endpoints × $10.80/month = ~$194.40/month
# Gateway Endpoints:    2 endpoints × $0.00        = $0.00
# Data Transfer:        ~$0.01/GB processed
# NAT Gateways (3):     3 × $32.40/month          = ~$97.20/month
# -----------------------------------------------------------
# Total VPC Endpoints:  ~$194/month
# Total NAT Gateways:   ~$97/month
# Combined Total:       ~$291/month
#
# COST COMPARISON (QA - 3 AZs):
# ------------------------------
# Option 1 - NAT Only (no endpoints):
#   - NAT: $97/month + data: ~$150/month = ~$247/month
#
# Option 2 - Endpoints + NAT (current):
#   - Endpoints: $194/month + NAT: $97/month + data: ~$30/month = ~$321/month
#
# Option 3 - Endpoints Only (no NAT for AWS services):
#   - Endpoints: $194/month + data: ~$30/month = ~$224/month (BEST)
#
# RECOMMENDATION FOR QA:
# - Keep endpoints enabled for production-like testing
# - Consider cost optimization by reducing to 2 AZs if budget constrained
# - Monitor actual usage and disable unused endpoints if needed
#
# BENEFITS:
# - Production parity for accurate testing
# - Enhanced security posture
# - Compliance testing (PCI-DSS, HIPAA)
# - Performance testing with AWS backbone


################################################################################
# Common Tags
################################################################################

common_tags = {
  Environment  = "qa"
  Project      = "myapp"
  ManagedBy    = "Terraform"
  CostCenter   = "engineering"
  Owner        = "qa-team"
  Backup       = "daily"
  DataClass    = "internal"
  TestingPhase = "integration"
}
