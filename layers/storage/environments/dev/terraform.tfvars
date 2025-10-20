# Storage Layer - Development Environment Configuration
# Version: 2.0 - Enhanced with EFS support

aws_region   = "us-east-1"
environment  = "dev"
project_name = "mycompany"

common_tags = {
  Environment = "dev"
  Project     = "mycompany"
  ManagedBy   = "terraform"
  Layer       = "storage"
  CostCenter  = "engineering"
}

################################################################################
# S3 Configuration
################################################################################

# Log retention - shorter for dev
logs_retention_days = 7

################################################################################
# EFS Configuration - Development
################################################################################

# Enable EFS if needed for shared storage
enable_efs = false  # Set to true when needed

# Performance - General Purpose for dev
efs_performance_mode = "generalPurpose"
efs_throughput_mode  = "bursting"  # Cost-effective

# One Zone storage for dev (47% cheaper than Regional)
efs_availability_zone_name = "us-east-1a"

# Encryption - optional in dev
efs_encrypted = false  # Set to true for sensitive data

# Lifecycle - aggressive transition to save costs
efs_transition_to_ia                    = "AFTER_7_DAYS"
efs_transition_to_primary_storage_class = "AFTER_1_ACCESS"

# Backup - not needed for dev
efs_enable_backup_policy = false

# Mount targets
efs_create_mount_targets = true

# Access points - optional
efs_access_points = {
  # Example:
  # dev_app = {
  #   posix_user = {
  #     gid = 1000
  #     uid = 1000
  #   }
  #   root_directory = {
  #     path = "/dev-app"
  #     creation_info = {
  #       owner_gid   = 1000
  #       owner_uid   = 1000
  #       permissions = "755"
  #     }
  #   }
  # }
}

# Replication - not needed for dev
efs_enable_replication = false

################################################################################
# S3 Configuration - Development
################################################################################

# S3 global settings
s3_force_destroy          = true  # Allow easy cleanup in dev
s3_enable_kms_encryption  = false # Optional for dev (save costs)
s3_enable_access_logging  = false # Disable to save costs

# Application bucket
s3_app_versioning_enabled = true

s3_app_lifecycle_rules = [
  {
    id      = "transition-to-ia"
    enabled = true
    transitions = [
      {
        days          = 30
        storage_class = "STANDARD_IA"
      }
    ]
  }
]

s3_app_intelligent_tiering  = {}
s3_app_replication_enabled  = false
s3_app_replication_rules    = {}

# Logs bucket lifecycle
s3_logs_lifecycle_enabled             = true
s3_logs_intelligent_tiering_enabled   = false
