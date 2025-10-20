# Database Layer - Production Environment Configuration  
# Version: 2.0 - Enhanced RDS configuration

aws_region   = "us-east-1"
environment  = "prod"
project_name = "mycompany"

common_tags = {
  Environment = "prod"
  Project     = "mycompany"
  ManagedBy   = "terraform"
  Layer       = "database"
  CostCenter  = "engineering"
  Compliance  = "required"
  Critical    = "true"
}

################################################################################
# RDS Configuration - Production
################################################################################

create_rds = false  # Set to true when needed

# Basic configuration - production grade
rds_engine         = "postgres"
rds_engine_version = "15.4"
rds_instance_type  = "db.r5.xlarge"  # Memory-optimized for production

# Storage - production with autoscaling
rds_allocated_storage     = 500
rds_max_allocated_storage = 2000  # Autoscale up to 2TB
rds_storage_type          = "gp3"
rds_iops                  = 12000
rds_storage_throughput    = 500

# Database
database_name   = "proddb"
master_username = "dbadmin"
master_password = null  # Not used when manage_master_user_password = true

# High availability - REQUIRED for production
enable_multi_az = true

# Backups - maximum retention for compliance
backup_retention_days = 35  # Maximum allowed
rds_backup_window     = "03:00-04:00"
rds_maintenance_window = "sun:04:00-sun:05:00"

# Monitoring - comprehensive for production
rds_cloudwatch_logs_exports = ["postgresql", "upgrade"]
rds_monitoring_interval     = 60  # Enhanced monitoring every minute
enable_performance_insights = true
rds_performance_insights_retention_period = 731  # 2 years

# Upgrades - controlled for production
rds_auto_minor_version_upgrade  = true   # Auto-patch for security
rds_allow_major_version_upgrade = false  # Manually controlled
rds_apply_immediately           = false  # Use maintenance window
rds_enable_blue_green_update    = true   # Zero-downtime updates

# Security - maximum for production
rds_publicly_accessible        = false  # NEVER public in production
rds_deletion_protection        = true   # Prevent accidental deletion
rds_skip_final_snapshot        = false  # ALWAYS take final snapshot
rds_iam_authentication_enabled = true   # Enable IAM auth

# Password management - RDS-managed for security
rds_manage_master_password = true  # RDS manages in Secrets Manager

# Parameter group - production tuning
rds_create_parameter_group = true
rds_parameter_group_family = "postgres15"

rds_parameters = [
  {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements,pg_hint_plan"
    apply_method = "pending-reboot"
  },
  {
    name  = "log_statement"
    value = "ddl"
  },
  {
    name  = "log_min_duration_statement"
    value = "1000"  # Log queries > 1s
  },
  {
    name  = "max_connections"
    value = "200"
  },
  {
    name  = "shared_buffers"
    value = "{DBInstanceClassMemory/4096}"  # 25% of RAM
  }
]

# Option group
rds_create_option_group  = false
rds_major_engine_version = "15"
rds_options = []

# Read replicas for scaling and HA
rds_read_replicas = {
  read1 = {
    instance_class               = "db.r5.large"
    multi_az                     = false
    availability_zone            = "us-east-1a"
    performance_insights_enabled = true
    monitoring_interval          = 60
    
    tags = {
      Role = "read-replica"
      AZ   = "us-east-1a"
    }
  }
  
  read2 = {
    instance_class               = "db.r5.large"
    multi_az                     = false
    availability_zone            = "us-east-1b"
    performance_insights_enabled = true
    monitoring_interval          = 60
    
    tags = {
      Role = "read-replica"
      AZ   = "us-east-1b"
    }
  }
}

################################################################################
# Production Database Notes
################################################################################

# IMPORTANT CONFIGURATION NOTES:
# 
# 1. Password Management:
#    - rds_manage_master_password = true (RDS manages in Secrets Manager)
#    - Retrieve password: aws secretsmanager get-secret-value --secret-id <arn>
#
# 2. Backups:
#    - 35-day retention for compliance
#    - Automated snapshots daily
#    - Final snapshot on deletion
#
# 3. High Availability:
#    - Multi-AZ enabled (automatic failover)
#    - 2 read replicas in different AZs
#    - Blue/green deployments for zero downtime
#
# 4. Monitoring:
#    - Enhanced monitoring (60-second granularity)
#    - Performance Insights (2-year retention)
#    - CloudWatch Logs exports
#
# 5. Security:
#    - Private subnets only
#    - KMS encryption
#    - IAM authentication enabled
#    - Deletion protection enabled
#
# 6. Scaling:
#    - Storage autoscaling (500GB → 2TB)
#    - Read replicas for read scaling
#    - Parameter tuning for performance
