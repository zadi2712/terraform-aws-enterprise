# Database Layer - UAT Environment Configuration
# Version: 2.0 - Enhanced RDS configuration

aws_region   = "us-east-1"
environment  = "uat"
project_name = "mycompany"

common_tags = {
  Environment = "uat"
  Project     = "mycompany"
  ManagedBy   = "terraform"
  Layer       = "database"
  CostCenter  = "engineering"
}

################################################################################
# RDS Configuration - UAT (Production-like)
################################################################################

create_rds = false  # Set to true when needed

# Basic configuration - production-like
rds_engine         = "postgres"
rds_engine_version = "15.4"
rds_instance_type  = "db.m5.large"

# Storage - production-like
rds_allocated_storage     = 100
rds_max_allocated_storage = 500  # Autoscale
rds_storage_type          = "gp3"
rds_iops                  = 3000
rds_storage_throughput    = 125

# Database
database_name   = "uatdb"
master_username = "dbadmin"
master_password = "CHANGE_ME"  # Or use Secrets Manager

# High availability - enabled for UAT
enable_multi_az = true

# Backups - production-like
backup_retention_days = 14
rds_backup_window     = "03:00-04:00"
rds_maintenance_window = "sun:04:00-sun:05:00"

# Monitoring - enhanced for UAT
rds_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
rds_monitoring_interval           = 60  # Enhanced monitoring every minute
enable_performance_insights       = true
rds_performance_insights_retention_period = 7

# Upgrades
rds_auto_minor_version_upgrade  = true
rds_allow_major_version_upgrade = false
rds_apply_immediately           = false
rds_enable_blue_green_update    = true  # Test blue/green in UAT

# Security - production-like
rds_publicly_accessible        = false
rds_deletion_protection        = true
rds_skip_final_snapshot        = false
rds_iam_authentication_enabled = true

# Password management - use RDS-managed
rds_manage_master_password = true  # RDS manages password in Secrets Manager

# Parameter group - custom tuning
rds_create_parameter_group = true
rds_parameter_group_family = "postgres15"

rds_parameters = [
  {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  },
  {
    name  = "log_statement"
    value = "ddl"
  }
]

# Option group
rds_create_option_group = false

# Read replicas - optional for UAT
rds_read_replicas = {
  # Example:
  # read1 = {
  #   instance_class = "db.m5.large"
  #   multi_az       = false
  # }
}
