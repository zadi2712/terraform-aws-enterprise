################################################################################
# EFS Module - Enterprise Shared File Storage
# Version: 2.0
# Description: Amazon EFS with encryption, backup, lifecycle, and access points
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  common_tags = merge(
    var.tags,
    {
      Module    = "efs"
      ManagedBy = "terraform"
    }
  )
}

################################################################################
# EFS File System
################################################################################

resource "aws_efs_file_system" "this" {
  creation_token   = var.creation_token != null ? var.creation_token : var.name
  performance_mode = var.performance_mode
  throughput_mode  = var.throughput_mode
  
  # Provisioned throughput (only for provisioned mode)
  provisioned_throughput_in_mibps = var.throughput_mode == "provisioned" ? var.provisioned_throughput_in_mibps : null

  # Encryption
  encrypted  = var.encrypted
  kms_key_id = var.encrypted && var.kms_key_id != null ? var.kms_key_id : null

  # Lifecycle management
  dynamic "lifecycle_policy" {
    for_each = var.transition_to_ia != null ? [1] : []
    
    content {
      transition_to_ia = var.transition_to_ia
    }
  }

  dynamic "lifecycle_policy" {
    for_each = var.transition_to_primary_storage_class != null ? [1] : []
    
    content {
      transition_to_primary_storage_class = var.transition_to_primary_storage_class
    }
  }

  # Protection
  dynamic "protection" {
    for_each = var.enable_replication_overwrite_protection ? [1] : []
    
    content {
      replication_overwrite = "ENABLED"
    }
  }

  # Availability and durability
  availability_zone_name = var.availability_zone_name

  tags = merge(
    local.common_tags,
    {
      Name = var.name
    }
  )
}

################################################################################
# EFS Backup Policy
################################################################################

resource "aws_efs_backup_policy" "this" {
  count = var.enable_backup_policy ? 1 : 0

  file_system_id = aws_efs_file_system.this.id

  backup_policy {
    status = "ENABLED"
  }
}

################################################################################
# EFS Mount Targets
################################################################################

resource "aws_efs_mount_target" "this" {
  for_each = var.create_mount_targets ? toset(var.subnet_ids) : toset([])

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = var.security_group_ids

  depends_on = [aws_efs_file_system.this]
}

################################################################################
# EFS Access Points
################################################################################

resource "aws_efs_access_point" "this" {
  for_each = var.access_points

  file_system_id = aws_efs_file_system.this.id

  # POSIX user
  dynamic "posix_user" {
    for_each = lookup(each.value, "posix_user", null) != null ? [each.value.posix_user] : []
    
    content {
      gid            = posix_user.value.gid
      uid            = posix_user.value.uid
      secondary_gids = lookup(posix_user.value, "secondary_gids", null)
    }
  }

  # Root directory
  dynamic "root_directory" {
    for_each = lookup(each.value, "root_directory", null) != null ? [each.value.root_directory] : []
    
    content {
      path = lookup(root_directory.value, "path", "/")
      
      dynamic "creation_info" {
        for_each = lookup(root_directory.value, "creation_info", null) != null ? [root_directory.value.creation_info] : []
        
        content {
          owner_gid   = creation_info.value.owner_gid
          owner_uid   = creation_info.value.owner_uid
          permissions = creation_info.value.permissions
        }
      }
    }
  }

  tags = merge(
    local.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = "${var.name}-${each.key}"
    }
  )
}

################################################################################
# EFS File System Policy
################################################################################

resource "aws_efs_file_system_policy" "this" {
  count = var.file_system_policy != null ? 1 : 0

  file_system_id = aws_efs_file_system.this.id
  policy         = var.file_system_policy
}

################################################################################
# EFS Replication Configuration
################################################################################

resource "aws_efs_replication_configuration" "this" {
  count = var.enable_replication ? 1 : 0

  source_file_system_id = aws_efs_file_system.this.id

  destination {
    region                 = var.replication_destination_region
    availability_zone_name = var.replication_destination_availability_zone
    kms_key_id            = var.replication_destination_kms_key_id
  }
}
