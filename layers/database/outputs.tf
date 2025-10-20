################################################################################
# RDS Outputs
################################################################################

output "rds_endpoint" {
  description = "RDS connection endpoint"
  value       = var.create_rds ? module.rds[0].db_instance_endpoint : null
}

output "rds_address" {
  description = "RDS hostname"
  value       = var.create_rds ? module.rds[0].db_instance_address : null
}

output "rds_port" {
  description = "RDS port"
  value       = var.create_rds ? module.rds[0].db_instance_port : null
}

output "rds_instance_id" {
  description = "RDS instance identifier"
  value       = var.create_rds ? module.rds[0].db_instance_id : null
}

output "rds_instance_arn" {
  description = "RDS instance ARN"
  value       = var.create_rds ? module.rds[0].db_instance_arn : null
}

output "rds_database_name" {
  description = "Database name"
  value       = var.create_rds ? module.rds[0].db_instance_name : null
}

output "rds_master_username" {
  description = "Master username"
  value       = var.create_rds ? module.rds[0].db_instance_username : null
  sensitive   = true
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = module.rds_security_group.security_group_id
}

output "rds_read_replica_endpoints" {
  description = "Map of read replica endpoints"
  value       = var.create_rds ? module.rds[0].read_replica_endpoints : {}
}

output "rds_master_password_secret_arn" {
  description = "ARN of Secrets Manager secret for master password"
  value       = var.create_rds ? module.rds[0].master_password_secret_arn : null
}

output "rds_performance_insights_enabled" {
  description = "Whether Performance Insights is enabled"
  value       = var.create_rds ? module.rds[0].performance_insights_enabled : null
}

output "rds_connection_info" {
  description = "Complete database connection information"
  value       = var.create_rds ? module.rds[0].connection_info : null
  sensitive   = true
}

output "rds_info" {
  description = "Complete RDS instance information"
  value       = var.create_rds ? module.rds[0].rds_info : null
}
