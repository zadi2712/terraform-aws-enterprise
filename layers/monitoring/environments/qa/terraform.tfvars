################################################################################
# MONITORING Layer - QA Environment Configuration
################################################################################

# General Configuration
environment  = "qa"
aws_region   = "us-east-1"
project_name = "enterprise"

# Instance Sizing
instance_type     = "t3.medium"
rds_instance_type = "db.t3.medium"
enable_multi_az   = true

# Backup Configuration
backup_retention_days = 14

# Common Tags
common_tags = {
  Environment = "qa"
  Project     = "enterprise-infrastructure"
  ManagedBy   = "terraform"
  Layer       = "monitoring"
  CostCenter  = "engineering"
  Owner       = "platform-team"
}
