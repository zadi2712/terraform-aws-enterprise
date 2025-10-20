################################################################################
# Cluster Outputs
################################################################################

output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.this.id
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.this.name
}

################################################################################
# IAM Role Outputs
################################################################################

output "task_execution_role_arn" {
  description = "ARN of the task execution role"
  value       = var.create_task_execution_role ? aws_iam_role.task_execution[0].arn : null
}

output "task_execution_role_name" {
  description = "Name of the task execution role"
  value       = var.create_task_execution_role ? aws_iam_role.task_execution[0].name : null
}

output "task_role_arn" {
  description = "ARN of the task role"
  value       = var.create_task_role ? aws_iam_role.task[0].arn : null
}

output "task_role_name" {
  description = "Name of the task role"
  value       = var.create_task_role ? aws_iam_role.task[0].name : null
}

################################################################################
# Security Group Outputs
################################################################################

output "security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = var.create_security_group ? aws_security_group.ecs_tasks[0].id : null
}

output "security_group_arn" {
  description = "Security group ARN for ECS tasks"
  value       = var.create_security_group ? aws_security_group.ecs_tasks[0].arn : null
}

################################################################################
# Service Discovery Outputs
################################################################################

output "service_discovery_namespace_id" {
  description = "Service discovery namespace ID"
  value       = var.enable_service_discovery ? aws_service_discovery_private_dns_namespace.this[0].id : null
}

output "service_discovery_namespace_arn" {
  description = "Service discovery namespace ARN"
  value       = var.enable_service_discovery ? aws_service_discovery_private_dns_namespace.this[0].arn : null
}

output "service_discovery_namespace_hosted_zone" {
  description = "Service discovery namespace Route53 hosted zone ID"
  value       = var.enable_service_discovery ? aws_service_discovery_private_dns_namespace.this[0].hosted_zone : null
}

################################################################################
# CloudWatch Outputs
################################################################################

output "exec_command_log_group_name" {
  description = "CloudWatch log group name for ECS Exec"
  value       = var.enable_execute_command ? aws_cloudwatch_log_group.exec_command[0].name : null
}

output "exec_command_log_group_arn" {
  description = "CloudWatch log group ARN for ECS Exec"
  value       = var.enable_execute_command ? aws_cloudwatch_log_group.exec_command[0].arn : null
}
