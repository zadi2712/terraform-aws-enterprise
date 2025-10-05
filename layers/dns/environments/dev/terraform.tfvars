################################################################################
# DNS Layer - DEV Environment Configuration
################################################################################

# General Configuration
environment  = "dev"
aws_region   = "us-east-1"
project_name = "enterprise"

# Instance Sizing
instance_type     = "t3.small"
rds_instance_type = "db.t3.small"
enable_multi_az   = false

# Backup Configuration
backup_retention_days = 7

# Common Tags
common_tags = {
  Environment = "dev"
  Project     = "enterprise-infrastructure"
  ManagedBy   = "terraform"
  Layer       = "dns"
  CostCenter  = "engineering"
  Owner       = "platform-team"
}
