################################################################################
# Storage Layer - PROD Environment Configuration
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
  Layer       = "storage"
  CostCenter  = "engineering"
  Owner       = "platform-team"
  Compliance  = "pci-dss"
}
