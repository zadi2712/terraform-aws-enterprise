################################################################################
# EFS Module - Outputs
# Version: 2.0
################################################################################

################################################################################
# File System Outputs
################################################################################

output "file_system_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.this.id
}

output "file_system_arn" {
  description = "ARN of the EFS file system"
  value       = aws_efs_file_system.this.arn
}

output "file_system_dns_name" {
  description = "DNS name of the EFS file system"
  value       = aws_efs_file_system.this.dns_name
}

output "file_system_size_in_bytes" {
  description = "Latest known size of the file system in bytes"
  value       = aws_efs_file_system.this.size_in_bytes
}

output "file_system_number_of_mount_targets" {
  description = "Current number of mount targets"
  value       = aws_efs_file_system.this.number_of_mount_targets
}

################################################################################
# Mount Target Outputs
################################################################################

output "mount_target_ids" {
  description = "List of EFS mount target IDs"
  value       = [for mt in aws_efs_mount_target.this : mt.id]
}

output "mount_target_network_interface_ids" {
  description = "List of EFS mount target network interface IDs"
  value       = [for mt in aws_efs_mount_target.this : mt.network_interface_id]
}

output "mount_target_dns_names" {
  description = "List of EFS mount target DNS names"
  value       = [for mt in aws_efs_mount_target.this : mt.dns_name]
}

output "mount_target_availability_zones" {
  description = "Map of mount targets by availability zone"
  value = {
    for mt in aws_efs_mount_target.this : mt.availability_zone => {
      id                     = mt.id
      dns_name               = mt.dns_name
      network_interface_id   = mt.network_interface_id
      ip_address             = mt.ip_address
    }
  }
}

################################################################################
# Access Point Outputs
################################################################################

output "access_point_ids" {
  description = "Map of access point IDs"
  value       = { for k, v in aws_efs_access_point.this : k => v.id }
}

output "access_point_arns" {
  description = "Map of access point ARNs"
  value       = { for k, v in aws_efs_access_point.this : k => v.arn }
}

output "access_points" {
  description = "Complete access point information"
  value = {
    for k, v in aws_efs_access_point.this : k => {
      id           = v.id
      arn          = v.arn
      file_system_arn = v.file_system_arn
    }
  }
}

################################################################################
# Replication Outputs
################################################################################

output "replication_configuration_id" {
  description = "ID of the replication configuration"
  value       = var.enable_replication ? aws_efs_replication_configuration.this[0].id : null
}

output "replication_destination_file_system_id" {
  description = "File system ID of the replication destination"
  value       = var.enable_replication ? aws_efs_replication_configuration.this[0].destination[0].file_system_id : null
}

output "replication_destination_status" {
  description = "Status of the replication destination"
  value       = var.enable_replication ? aws_efs_replication_configuration.this[0].destination[0].status : null
}

################################################################################
# Mount Command Outputs
################################################################################

output "mount_command_nfs" {
  description = "NFS mount command for the file system"
  value       = "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_file_system.this.dns_name}:/ /mnt/efs"
}

output "mount_command_efs_utils" {
  description = "EFS utils mount command (recommended)"
  value       = "sudo mount -t efs -o tls ${aws_efs_file_system.this.id}:/ /mnt/efs"
}

output "mount_commands_by_access_point" {
  description = "Mount commands for each access point"
  value = {
    for k, v in aws_efs_access_point.this : k => "sudo mount -t efs -o tls,accesspoint=${v.id} ${aws_efs_file_system.this.id}:/ /mnt/efs/${k}"
  }
}

################################################################################
# Summary Output
################################################################################

output "efs_info" {
  description = "Complete EFS file system information"
  value = {
    file_system_id        = aws_efs_file_system.this.id
    file_system_arn       = aws_efs_file_system.this.arn
    dns_name              = aws_efs_file_system.this.dns_name
    encrypted             = aws_efs_file_system.this.encrypted
    performance_mode      = aws_efs_file_system.this.performance_mode
    throughput_mode       = aws_efs_file_system.this.throughput_mode
    availability_zone     = aws_efs_file_system.this.availability_zone_name
    mount_targets_count   = length(aws_efs_mount_target.this)
    access_points_count   = length(aws_efs_access_point.this)
    backup_enabled        = var.enable_backup_policy
    replication_enabled   = var.enable_replication
  }
}
