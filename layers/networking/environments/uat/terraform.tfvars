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
one_nat_gateway_per_az = true  # One NAT per AZ for redundancy (3 NAT Gateways)

################################################################################
# VPC Features
################################################################################

enable_flow_logs         = true
flow_logs_retention_days = 60   # Extended retention for UAT

################################################################################
# VPC Endpoints Configuration
################################################################################

# Enable VPC endpoints for AWS services (production-mirrored setup)
enable_vpc_endpoints = true

# PRODUCTION-MIRRORED CONFIGURATION
# ----------------------------------
# UAT environment mirrors production to ensure accurate acceptance testing.
# All 20 VPC endpoints are deployed across 3 availability zones.
#
# INTERFACE ENDPOINTS (18 total):
#   Compute:      ec2, ecr.api, ecr.dkr, ecs, ecs-telemetry, lambda, autoscaling
#   Security:     kms, secretsmanager, sts
#   Monitoring:   logs, monitoring, events
#   Database:     rds, elasticache
#   Messaging:    sns, sqs
#   Management:   ssm
#   Networking:   elasticloadbalancing
#
# GATEWAY ENDPOINTS (2 total - FREE):
#   Storage:      s3, dynamodb
#
# COST ESTIMATE (UAT - 3 AZs, Production-Mirror):
# ------------------------------------------------
# VPC Endpoints:
#   - Interface Endpoints: 18 × $10.80/month = ~$194.40/month
#   - Gateway Endpoints:    2 × $0.00        = $0.00
#   - Data Transfer:        ~$0.01/GB        = ~$30/month (est.)
#   Subtotal:                                  ~$224/month
#
# NAT Gateways (3):
#   - Hourly Rate:          3 × $32.40/month = ~$97.20/month
#   - Data Transfer:        ~$0.045/GB       = ~$50/month (est.)
#   Subtotal:                                  ~$147/month
#
# Total Infrastructure Cost:                   ~$371/month
#
# ALTERNATIVE CONFIGURATIONS:
# ---------------------------
# 1. Cost-Optimized (2 AZs instead of 3):
#    - Reduces costs by ~33%
#    - Estimated: ~$248/month
#    - Trade-off: Lower availability
#
# 2. Endpoints-Only (remove NAT for AWS traffic):
#    - Keep NAT only for non-AWS internet traffic
#    - Estimated: ~$250/month
#    - Trade-off: None (recommended approach)
#
# 3. NAT-Only (disable endpoints):
#    - Set enable_vpc_endpoints = false
#    - Estimated: ~$247/month
#    - Trade-off: Higher latency, less secure, no compliance benefits
#
# RECOMMENDATION FOR UAT:
# -----------------------
# ✅ Keep current configuration (endpoints + NAT)
#    - Ensures production parity for acceptance testing
#    - Validates security posture before production
#    - Tests compliance requirements
#    - Verifies performance characteristics
#    - Cost: ~$371/month (acceptable for pre-production)
#
# BENEFITS FOR UAT:
# -----------------
# ✅ Production Parity     - Exact match with production environment
# ✅ Security Testing      - Validates security controls work correctly
# ✅ Performance Testing   - Tests with production-like latency
# ✅ Compliance Validation - Verifies PCI-DSS, HIPAA compatibility
# ✅ Risk Mitigation       - Catches issues before production
# ✅ User Confidence       - Business users test in prod-like environment

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
