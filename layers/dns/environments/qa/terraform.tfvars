################################################################################
# Dns Layer - QA Environment Configuration
################################################################################

# General Configuration
environment  = "qa"
aws_region   = "us-east-1"
project_name = "enterprise"

# Common Tags
common_tags = {
  Environment = "qa"
  Project     = "enterprise-infrastructure"
  ManagedBy   = "terraform"
  Layer       = "dns"
  CostCenter  = "engineering"
  Owner       = "platform-team"
  Compliance  = "pci-dss"
}
