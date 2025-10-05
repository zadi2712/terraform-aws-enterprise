################################################################################
# Compute Layer - PROD Environment Configuration
################################################################################

# General Configuration
environment  = "prod"
aws_region   = "us-east-1"
project_name = "enterprise"

# Common Tags
common_tags = {
  Environment = "prod"
  Project     = "enterprise-infrastructure"
  ManagedBy   = "terraform"
  Layer       = "compute"
  CostCenter  = "engineering"
  Owner       = "platform-team"
  Compliance  = "pci-dss"
}
