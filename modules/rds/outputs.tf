################################################################################
# RDS Module - Outputs
# Version: 2.0
################################################################################

################################################################################
# DB Instance Outputs
################################################################################

output "db_instance_id" {
  description = "Database instance identifier"
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "Database instance ARN"
  value       = aws_db_instance.this.arn
}

output "db_instance_endpoint" {
  description = "Database connection endpoint"
  value       = aws_db_instance.this.endpoint
}

output "db_instance_address" {
  description = "Database hostname"
  value       = aws_db_instance.this.address
}

output "db_instance_port" {
  description = "Database port"
  value       = aws_db_instance.this.port
}

output "db_instance_name" {
  description = "Database name"
  value       = aws_db_instance.this.db_name
}

output "db_instance_username" {
  description = "Master username"
  value       = aws_db_instance.this.username
  sensitive   = true
}

output "db_instance_engine" {
  description = "Database engine"
  value       = aws_db_instance.this.engine
}

output "db_instance_engine_version" {
  description = "Database engine version"
  value       = aws_db_instance.this.engine_version_actual
}

output "db_instance_status" {
  description = "Database instance status"
  value       = aws_db_instance.this.status
}

output "db_instance_resource_id" {
  description = "RDS resource ID"
  value       = aws_db_instance.this.resource_id
}

output "db_instance_hosted_zone_id" {
  description = "Hosted zone ID for the DB instance"
  value       = aws_db_instance.this.hosted_zone_id
}

################################################################################
# Subnet Group Outputs
################################################################################

output "db_subnet_group_id" {
  description = "DB subnet group ID"
  value       = var.create_db_subnet_group ? aws_db_subnet_group.this[0].id : var.db_subnet_group_name
}

output "db_subnet_group_arn" {
  description = "DB subnet group ARN"
  value       = var.create_db_subnet_group ? aws_db_subnet_group.this[0].arn : null
}

################################################################################
# Parameter Group Outputs
################################################################################

output "db_parameter_group_id" {
  description = "DB parameter group ID"
  value       = var.create_parameter_group ? aws_db_parameter_group.this[0].id : var.parameter_group_name
}

output "db_parameter_group_arn" {
  description = "DB parameter group ARN"
  value       = var.create_parameter_group ? aws_db_parameter_group.this[0].arn : null
}

################################################################################
# Option Group Outputs
################################################################################

output "db_option_group_id" {
  description = "DB option group ID"
  value       = var.create_option_group ? aws_db_option_group.this[0].id : var.option_group_name
}

output "db_option_group_arn" {
  description = "DB option group ARN"
  value       = var.create_option_group ? aws_db_option_group.this[0].arn : null
}

################################################################################
# Monitoring Outputs
################################################################################

output "enhanced_monitoring_role_arn" {
  description = "Enhanced monitoring IAM role ARN"
  value       = var.create_monitoring_role && var.monitoring_interval > 0 ? aws_iam_role.enhanced_monitoring[0].arn : var.monitoring_role_arn
}

output "performance_insights_enabled" {
  description = "Whether Performance Insights is enabled"
  value       = aws_db_instance.this.performance_insights_enabled
}

################################################################################
# Read Replica Outputs
################################################################################

output "read_replica_ids" {
  description = "Map of read replica identifiers"
  value       = { for k, v in aws_db_instance.replica : k => v.id }
}

output "read_replica_endpoints" {
  description = "Map of read replica endpoints"
  value       = { for k, v in aws_db_instance.replica : k => v.endpoint }
}

output "read_replica_arns" {
  description = "Map of read replica ARNs"
  value       = { for k, v in aws_db_instance.replica : k => v.arn }
}

output "read_replicas" {
  description = "Complete read replica information"
  value = {
    for k, v in aws_db_instance.replica : k => {
      id       = v.id
      endpoint = v.endpoint
      address  = v.address
      port     = v.port
      arn      = v.arn
    }
  }
}

################################################################################
# Secrets Manager Outputs
################################################################################

output "master_password_secret_arn" {
  description = "ARN of Secrets Manager secret for master password"
  value       = var.store_master_password_in_secrets_manager && !var.manage_master_user_password ? aws_secretsmanager_secret.db_credentials[0].arn : (
    var.manage_master_user_password ? aws_db_instance.this.master_user_secret[0].secret_arn : null
  )
}

output "master_password_secret_name" {
  description = "Name of Secrets Manager secret"
  value       = var.store_master_password_in_secrets_manager && !var.manage_master_user_password ? aws_secretsmanager_secret.db_credentials[0].name : null
}

################################################################################
# Connection Information Output
################################################################################

output "connection_info" {
  description = "Database connection information"
  value = {
    endpoint = aws_db_instance.this.endpoint
    address  = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    database = aws_db_instance.this.db_name
    username = aws_db_instance.this.username
    engine   = aws_db_instance.this.engine
  }
  sensitive = true
}

output "connection_string_psql" {
  description = "PostgreSQL connection string"
  value       = var.engine == "postgres" ? "psql postgresql://${aws_db_instance.this.username}:PASSWORD@${aws_db_instance.this.address}:${aws_db_instance.this.port}/${aws_db_instance.this.db_name}" : null
  sensitive   = true
}

output "connection_string_mysql" {
  description = "MySQL connection string"
  value       = contains(["mysql", "mariadb"], var.engine) ? "mysql -h ${aws_db_instance.this.address} -P ${aws_db_instance.this.port} -u ${aws_db_instance.this.username} -p ${aws_db_instance.this.db_name}" : null
  sensitive   = true
}

################################################################################
# Summary Output
################################################################################

output "rds_info" {
  description = "Complete RDS instance information"
  value = {
    identifier           = aws_db_instance.this.id
    arn                  = aws_db_instance.this.arn
    endpoint             = aws_db_instance.this.endpoint
    engine               = aws_db_instance.this.engine
    engine_version       = aws_db_instance.this.engine_version_actual
    instance_class       = aws_db_instance.this.instance_class
    allocated_storage    = aws_db_instance.this.allocated_storage
    storage_encrypted    = aws_db_instance.this.storage_encrypted
    multi_az             = aws_db_instance.this.multi_az
    availability_zone    = aws_db_instance.this.availability_zone
    backup_retention     = aws_db_instance.this.backup_retention_period
    performance_insights = aws_db_instance.this.performance_insights_enabled
    read_replicas_count  = length(aws_db_instance.replica)
  }
}
