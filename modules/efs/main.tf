################################################################################
# EFS Module - Main Configuration
# Description: EFS file systems
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Module    = "efs"
      ManagedBy = "terraform"
    }
  )
}

# Add your resource configurations here
# Resources: aws_efs_file_system, aws_efs_mount_target
