# Database Layer - Development Environment Configuration
# Version: 2.0 - Enhanced RDS configuration

aws_region   = "us-east-1"
environment  = "dev"
project_name = "mycompany"

common_tags = {
  Environment = "dev"
  Project     = "mycompany"
  ManagedBy   = "terraform"
  Layer       = "database"
  CostCenter  = "engineering"
}

################################################################################
# RDS Configuration - Development
################################################################################

# Enable RDS if needed (disabled by default to save costs)
create_rds = false  # Set to true when you need a database

# Basic configuration
rds_engine         = "postgres"
rds_engine_version = "15.4"
rds_instance_type  = "db.t3.micro"  # Smallest for dev

# Storage - minimal for dev
rds_allocated_storage     = 20
rds_max_allocated_storage = 100  # Autoscale up to 100GB
rds_storage_type          = "gp3"
rds_iops                  = null
rds_storage_throughput    = null

# Database
database_name   = "devdb"
master_username = "dbadmin"
master_password = "CHANGE_ME_IN_PROD"  # Use terraform.tfvars.secret or env var

# High availability - disabled for dev to save costs
enable_multi_az = false

# Backups - minimal for dev
backup_retention_days = 3
rds_backup_window     = "03:00-04:00"
rds_maintenance_window = "sun:04:00-sun:05:00"

# Monitoring - basic for dev
rds_cloudwatch_logs_exports       = ["postgresql"]
rds_monitoring_interval           = 0   # Disable enhanced monitoring
enable_performance_insights       = false
rds_performance_insights_retention_period = 7

# Upgrades
rds_auto_minor_version_upgrade = true
rds_allow_major_version_upgrade = false
rds_apply_immediately = false
rds_enable_blue_green_update = false

# Security - relaxed for dev
rds_publicly_accessible   = false
rds_deletion_protection   = false  # Allow easy deletion
rds_skip_final_snapshot   = true   # Skip final snapshot
rds_iam_authentication_enabled = false

# Password management
rds_manage_master_password = false  # Set to true to use RDS-managed passwords
rds_store_password_in_secrets_manager = false

# Parameter group
rds_create_parameter_group = false
rds_parameter_group_family = "postgres15"
rds_parameters = []

# Option group
rds_create_option_group = false
rds_major_engine_version = ""
rds_options = []

# Read replicas - none for dev
rds_read_replicas = {}
