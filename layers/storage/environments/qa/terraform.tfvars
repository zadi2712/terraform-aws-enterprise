# Storage Layer - QA Environment Configuration
# Version: 2.0 - Enhanced with EFS support

aws_region   = "us-east-1"
environment  = "qa"
project_name = "mycompany"

common_tags = {
  Environment = "qa"
  Project     = "mycompany"
  ManagedBy   = "terraform"
  Layer       = "storage"
  CostCenter  = "engineering"
}

################################################################################
# S3 Configuration
################################################################################

logs_retention_days = 14

################################################################################
# EFS Configuration - QA
################################################################################

# Enable EFS if needed
enable_efs = false  # Set to true when needed

# Performance - General Purpose
efs_performance_mode = "generalPurpose"
efs_throughput_mode  = "bursting"

# Regional storage for QA (multi-AZ)
efs_availability_zone_name = null

# Encryption - recommended for QA
efs_encrypted = true

# Lifecycle - moderate transition
efs_transition_to_ia                    = "AFTER_14_DAYS"
efs_transition_to_primary_storage_class = "AFTER_1_ACCESS"

# Backup - optional for QA
efs_enable_backup_policy = false

# Mount targets
efs_create_mount_targets = true

# Access points
efs_access_points = {}

# Replication - not needed for QA
efs_enable_replication = false

################################################################################
# S3 Configuration - QA
################################################################################

s3_force_destroy          = true
s3_enable_kms_encryption  = true
s3_enable_access_logging  = false

s3_app_versioning_enabled = true
s3_app_lifecycle_rules = [
  {
    id      = "transition"
    enabled = true
    transitions = [
      {
        days          = 30
        storage_class = "STANDARD_IA"
      },
      {
        days          = 90
        storage_class = "GLACIER"
      }
    ]
  }
]

s3_app_intelligent_tiering  = {}
s3_app_replication_enabled  = false
s3_logs_lifecycle_enabled   = true
s3_logs_intelligent_tiering_enabled = false
