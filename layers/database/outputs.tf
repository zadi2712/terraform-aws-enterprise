output "rds_endpoint" {
  description = "RDS endpoint"
  value       = var.create_rds ? module.rds[0].db_instance_endpoint : null
}

output "rds_instance_id" {
  description = "RDS instance ID"
  value       = var.create_rds ? module.rds[0].db_instance_id : null
}
