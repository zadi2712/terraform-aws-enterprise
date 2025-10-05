################################################################################
# Dns Layer - UAT Environment Configuration
################################################################################

# General Configuration
environment  = "uat"
aws_region   = "us-east-1"
project_name = "enterprise"

# Common Tags
common_tags = {
  Environment = "uat"
  Project     = "enterprise-infrastructure"
  ManagedBy   = "terraform"
  Layer       = "dns"
  CostCenter  = "engineering"
  Owner       = "platform-team"
  Compliance  = "pci-dss"
}
