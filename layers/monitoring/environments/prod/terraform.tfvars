################################################################################
# MONITORING Layer - PROD Environment Configuration
################################################################################

# General Configuration
environment  = "prod"
aws_region   = "us-east-1"
project_name = "enterprise"

# Instance Sizing
instance_type     = "t3.xlarge"
rds_instance_type = "db.r5.xlarge"
enable_multi_az   = true

# Backup Configuration
backup_retention_days = 90

# Common Tags
common_tags = {
  Environment = "prod"
  Project     = "enterprise-infrastructure"
  ManagedBy   = "terraform"
  Layer       = "monitoring"
  CostCenter  = "engineering"
  Owner       = "platform-team"
}
