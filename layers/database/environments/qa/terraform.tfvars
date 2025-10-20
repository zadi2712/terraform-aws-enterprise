# Database Layer - QA Environment Configuration
# Version: 2.0 - Enhanced RDS configuration

aws_region   = "us-east-1"
environment  = "qa"
project_name = "mycompany"

common_tags = {
  Environment = "qa"
  Project     = "mycompany"
  ManagedBy   = "terraform"
  Layer       = "database"
  CostCenter  = "engineering"
}

################################################################################
# RDS Configuration - QA
################################################################################

create_rds = false  # Set to true when needed

# Basic configuration
rds_engine         = "postgres"
rds_engine_version = "15.4"
rds_instance_type  = "db.t3.small"

# Storage
rds_allocated_storage     = 50
rds_max_allocated_storage = 200
rds_storage_type          = "gp3"

# Database
database_name   = "qadb"
master_username = "dbadmin"
master_password = "CHANGE_ME"

# High availability - optional for QA
enable_multi_az = false

# Backups
backup_retention_days = 7
rds_backup_window     = "03:00-04:00"
rds_maintenance_window = "sun:04:00-sun:05:00"

# Monitoring
rds_cloudwatch_logs_exports = ["postgresql", "upgrade"]
rds_monitoring_interval     = 0
enable_performance_insights = false

# Upgrades
rds_auto_minor_version_upgrade = true
rds_enable_blue_green_update   = false

# Security
rds_publicly_accessible        = false
rds_deletion_protection        = false
rds_skip_final_snapshot        = true
rds_iam_authentication_enabled = false

# Password management
rds_manage_master_password = false

# Parameter/Option groups
rds_create_parameter_group = false
rds_create_option_group = false

# Read replicas
rds_read_replicas = {}
