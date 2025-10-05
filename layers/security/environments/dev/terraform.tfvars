################################################################################
# Security Layer - DEV Environment Configuration
################################################################################

# General Configuration
environment  = "dev"
aws_region   = "us-east-1"
project_name = "enterprise"

# Common Tags
common_tags = {
  Environment = "dev"
  Project     = "enterprise-infrastructure"
  ManagedBy   = "terraform"
  Layer       = "security"
  CostCenter  = "engineering"
  Owner       = "platform-team"
  Compliance  = "pci-dss"
}
