output "db_instance_id" {
  description = "Database instance ID"
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "Database instance ARN"
  value       = aws_db_instance.this.arn
}

output "db_instance_endpoint" {
  description = "Database endpoint"
  value       = aws_db_instance.this.endpoint
}

output "db_instance_address" {
  description = "Database address"
  value       = aws_db_instance.this.address
}

output "db_instance_port" {
  description = "Database port"
  value       = aws_db_instance.this.port
}
