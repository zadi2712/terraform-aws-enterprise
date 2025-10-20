# Storage Layer - UAT Environment Configuration
# Version: 2.0 - Enhanced with EFS support

aws_region   = "us-east-1"
environment  = "uat"
project_name = "mycompany"

common_tags = {
  Environment = "uat"
  Project     = "mycompany"
  ManagedBy   = "terraform"
  Layer       = "storage"
  CostCenter  = "engineering"
}

################################################################################
# S3 Configuration
################################################################################

logs_retention_days = 30

################################################################################
# EFS Configuration - UAT (Production-like)
################################################################################

# Enable EFS for UAT testing
enable_efs = false  # Set to true when needed

# Performance - Production-like
efs_performance_mode = "generalPurpose"
efs_throughput_mode  = "elastic"  # Auto-scaling throughput

# Regional storage (multi-AZ) for production-like testing
efs_availability_zone_name = null

# Encryption - enabled for UAT
efs_encrypted = true

# Lifecycle - production-like settings
efs_transition_to_ia                    = "AFTER_30_DAYS"
efs_transition_to_primary_storage_class = "AFTER_1_ACCESS"

# Backup - enabled for UAT
efs_enable_backup_policy = true

# Mount targets in all AZs
efs_create_mount_targets = true

# Access points - define as needed
efs_access_points = {
  # Example for application storage
  app = {
    posix_user = {
      gid = 1000
      uid = 1000
    }
    root_directory = {
      path = "/app"
      creation_info = {
        owner_gid   = 1000
        owner_uid   = 1000
        permissions = "755"
      }
    }
  }
}

# Replication - optional for UAT
efs_enable_replication = false

################################################################################
# S3 Configuration - UAT (Production-like)
################################################################################

s3_force_destroy          = false
s3_enable_kms_encryption  = true
s3_enable_access_logging  = true

s3_app_versioning_enabled = true

s3_app_lifecycle_rules = [
  {
    id      = "lifecycle-management"
    enabled = true
    transitions = [
      {
        days          = 30
        storage_class = "STANDARD_IA"
      },
      {
        days          = 90
        storage_class = "GLACIER_IR"
      }
    ]
    noncurrent_version_transitions = [
      {
        noncurrent_days = 30
        storage_class   = "STANDARD_IA"
      }
    ]
    noncurrent_version_expiration = {
      noncurrent_days = 90
    }
  }
]

s3_app_intelligent_tiering = {}
s3_app_replication_enabled = false
s3_logs_lifecycle_enabled = true
s3_logs_intelligent_tiering_enabled = false
