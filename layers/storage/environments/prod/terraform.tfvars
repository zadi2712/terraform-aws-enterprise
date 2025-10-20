# Storage Layer - Production Environment Configuration
# Version: 2.0 - Enhanced with EFS support

aws_region   = "us-east-1"
environment  = "prod"
project_name = "mycompany"

common_tags = {
  Environment = "prod"
  Project     = "mycompany"
  ManagedBy   = "terraform"
  Layer       = "storage"
  CostCenter  = "engineering"
  Compliance  = "required"
}

################################################################################
# S3 Configuration
################################################################################

logs_retention_days = 90

################################################################################
# EFS Configuration - Production
################################################################################

# Enable EFS for production shared storage
enable_efs = false  # Set to true when needed

# Performance - General Purpose (recommended for most workloads)
efs_performance_mode = "generalPurpose"

# Throughput - Elastic mode (automatically scales)
efs_throughput_mode = "elastic"

# Regional storage (multi-AZ) for high availability
efs_availability_zone_name = null

# Encryption - mandatory for production
efs_encrypted = true

# Lifecycle management - save costs with IA storage
efs_transition_to_ia                    = "AFTER_30_DAYS"
efs_transition_to_primary_storage_class = "AFTER_1_ACCESS"

# Backup - enabled for production
efs_enable_backup_policy = true

# Mount targets - create in all private subnets
efs_create_mount_targets = true

# Access points - define for each application/service
efs_access_points = {
  # Example: Application shared storage
  app_shared = {
    posix_user = {
      gid = 1000
      uid = 1000
    }
    root_directory = {
      path = "/app-shared"
      creation_info = {
        owner_gid   = 1000
        owner_uid   = 1000
        permissions = "755"
      }
    }
    tags = {
      Application = "backend"
    }
  }
  
  # Example: Uploads directory
  uploads = {
    posix_user = {
      gid = 1001
      uid = 1001
    }
    root_directory = {
      path = "/uploads"
      creation_info = {
        owner_gid   = 1001
        owner_uid   = 1001
        permissions = "775"
      }
    }
    tags = {
      Purpose = "user-uploads"
    }
  }
}

# File system policy (optional)
efs_file_system_policy = null

# Replication - enable for disaster recovery
efs_enable_replication             = false  # Set to true for DR
efs_replication_destination_region = "us-west-2"
# efs_replication_destination_kms_key_id = "arn:aws:kms:us-west-2:ACCOUNT_ID:key/xxxxx"

################################################################################
# Production Notes
################################################################################

# When enabling EFS in production:
# 1. Set enable_efs = true
# 2. Define access points for your applications
# 3. Verify encryption is enabled
# 4. Enable backup policy
# 5. Consider replication for DR
# 6. Review and set file system policy if needed
# 7. Monitor EFS metrics in CloudWatch

################################################################################
# S3 Configuration - Production
################################################################################

# S3 global settings
s3_force_destroy          = false  # Never allow in production
s3_enable_kms_encryption  = true   # Always encrypt in production
s3_enable_access_logging  = true   # Enable logging for audit

# Application bucket configuration
s3_app_versioning_enabled = true

s3_app_lifecycle_rules = [
  {
    id      = "intelligent-lifecycle"
    enabled = true
    
    transitions = [
      {
        days          = 30
        storage_class = "STANDARD_IA"
      },
      {
        days          = 90
        storage_class = "GLACIER_IR"
      },
      {
        days          = 180
        storage_class = "GLACIER"
      }
    ]
    
    noncurrent_version_transitions = [
      {
        noncurrent_days = 30
        storage_class   = "STANDARD_IA"
      },
      {
        noncurrent_days = 90
        storage_class   = "GLACIER"
      }
    ]
    
    noncurrent_version_expiration = {
      noncurrent_days = 180
    }
    
    abort_incomplete_multipart_upload_days = 7
  }
]

# Intelligent Tiering for cost optimization
s3_app_intelligent_tiering = {
  entire_bucket = {
    tierings = [
      {
        access_tier = "ARCHIVE_ACCESS"
        days        = 90
      },
      {
        access_tier = "DEEP_ARCHIVE_ACCESS"
        days        = 180
      }
    ]
  }
}

# Replication for disaster recovery (optional)
s3_app_replication_enabled = false  # Set to true for DR
# s3_app_replication_rules = {
#   dr_replica = {
#     destination_bucket = "arn:aws:s3:::myapp-prod-dr-ACCOUNT_ID"
#     replica_kms_key_id = "arn:aws:kms:us-west-2:ACCOUNT_ID:key/xxxxx"
#     replication_time_enabled = true
#     delete_marker_replication = true
#   }
# }

# Logs bucket lifecycle
s3_logs_lifecycle_enabled           = true
s3_logs_intelligent_tiering_enabled = true
