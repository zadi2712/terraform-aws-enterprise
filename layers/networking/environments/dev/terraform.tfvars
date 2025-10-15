################################################################################
# Development Environment - Terraform Configuration
# Cost-Optimized Setup for Development and Testing
################################################################################

# Project Configuration
project_name = "myapp"
environment  = "dev"
aws_region   = "us-east-1"

################################################################################
# VPC Configuration
################################################################################

vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# Subnet CIDR Blocks
public_subnet_cidrs = [
  "10.0.1.0/24", # us-east-1a
  "10.0.2.0/24", # us-east-1b
]

private_subnet_cidrs = [
  "10.0.11.0/24", # us-east-1a
  "10.0.12.0/24", # us-east-1b
]

database_subnet_cidrs = [
  "10.0.21.0/24", # us-east-1a
  "10.0.22.0/24", # us-east-1b
]

################################################################################
# NAT Gateway Configuration (Cost-Optimized)
################################################################################

enable_nat_gateway     = true
single_nat_gateway     = true  # Single NAT for cost savings in dev
one_nat_gateway_per_az = false # Disabled for single NAT

################################################################################
# VPC Features
################################################################################

enable_flow_logs         = true
flow_logs_retention_days = 7 # Short retention for dev

################################################################################
# VPC Endpoints Configuration
################################################################################

# Enable VPC endpoints for AWS services (reduces NAT Gateway costs)
enable_vpc_endpoints = true

# When enabled, the following 20 VPC endpoints are created automatically:
#
# INTERFACE ENDPOINTS (18 total - deployed across 2 AZs):
# --------------------------------------------------------
# Compute & Container Services:
#   - ec2                      - EC2 API access
#   - ecr.api, ecr.dkr         - Container registry
#   - ecs, ecs-telemetry       - Container orchestration
#   - lambda                   - Serverless functions
#   - autoscaling              - Auto Scaling groups
#
# Security & Identity:
#   - kms                      - Encryption key management
#   - secretsmanager           - Secrets storage
#   - sts                      - Security Token Service
#
# Monitoring & Logging:
#   - logs                     - CloudWatch Logs
#   - monitoring               - CloudWatch Monitoring
#   - events                   - EventBridge
#
# Database & Storage:
#   - rds                      - Relational databases
#   - elasticache              - In-memory cache
#
# Messaging & Integration:
#   - sns                      - Notifications
#   - sqs                      - Message queuing
#
# Systems Management:
#   - ssm                      - Systems Manager
#
# Load Balancing:
#   - elasticloadbalancing     - Load balancers
#
# GATEWAY ENDPOINTS (2 total - FREE):
# -----------------------------------
#   - s3                       - Object storage (FREE)
#   - dynamodb                 - NoSQL database (FREE)
#
# COST ESTIMATE (DEV - 2 AZs):
# -----------------------------
# Interface Endpoints: 18 endpoints × $7.20/month = ~$129.60/month
# Gateway Endpoints:    2 endpoints × $0.00        = $0.00
# Data Transfer:        ~$0.01/GB (vs $0.045/GB NAT)
# -----------------------------------------------------------
# Total Estimated Cost: ~$130/month
#
# COST SAVINGS:
# - Gateway endpoints (S3, DynamoDB) save ~$40-80/month vs NAT Gateway
# - Interface endpoint data transfer is ~78% cheaper than NAT Gateway
# - Total estimated savings: ~$50-100/month despite endpoint costs
#
# BENEFITS:
# - Enhanced security (no public internet exposure)
# - Lower latency (AWS backbone network)
# - Better reliability (AWS-managed infrastructure)
# - Compliance-ready (PCI-DSS, HIPAA compatible)
#
# To disable endpoints and use only NAT Gateway, set: enable_vpc_endpoints = false

################################################################################
# Common Tags
################################################################################

common_tags = {
  Environment = "dev"
  Project     = "myapp"
  ManagedBy   = "Terraform"
  CostCenter  = "engineering"
  Owner       = "devops-team"
  Backup      = "no"
  DataClass   = "internal"
}
