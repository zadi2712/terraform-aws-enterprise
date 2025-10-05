################################################################################
# DNS Layer - UAT Environment Configuration
################################################################################

# General Configuration
environment  = "uat"
aws_region   = "us-east-1"
project_name = "enterprise"

# Instance Sizing
instance_type     = "t3.large"
rds_instance_type = "db.r5.large"
enable_multi_az   = true

# Backup Configuration
backup_retention_days = 30

# Common Tags
common_tags = {
  Environment = "uat"
  Project     = "enterprise-infrastructure"
  ManagedBy   = "terraform"
  Layer       = "dns"
  CostCenter  = "engineering"
  Owner       = "platform-team"
}
