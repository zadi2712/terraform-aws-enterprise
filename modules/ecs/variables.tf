################################################################################
# Required Variables
################################################################################

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

################################################################################
# Cluster Configuration
################################################################################

variable "container_insights_enabled" {
  description = "Enable Container Insights"
  type        = bool
  default     = true
}

variable "capacity_providers" {
  description = "Capacity providers"
  type        = list(string)
  default     = ["FARGATE", "FARGATE_SPOT"]
}

variable "default_capacity_provider_strategy" {
  description = "Default capacity provider strategy"
  type        = list(any)
  default     = []
}

################################################################################
# Network Configuration
################################################################################

variable "vpc_id" {
  description = "VPC ID for ECS tasks and service discovery"
  type        = string
  default     = null
}

variable "create_security_group" {
  description = "Whether to create a security group for ECS tasks"
  type        = bool
  default     = false
}

variable "alb_security_group_id" {
  description = "Security group ID of ALB to allow ingress from"
  type        = string
  default     = null
}

variable "task_container_port" {
  description = "Container port for tasks (used in security group rules)"
  type        = number
  default     = 8080
}

################################################################################
# Service Discovery
################################################################################

variable "enable_service_discovery" {
  description = "Enable AWS Cloud Map service discovery"
  type        = bool
  default     = false
}

variable "service_discovery_namespace" {
  description = "Service discovery namespace (e.g., local, internal)"
  type        = string
  default     = "local"
}

################################################################################
# IAM Configuration
################################################################################

variable "create_task_execution_role" {
  description = "Whether to create a task execution role"
  type        = bool
  default     = false
}

variable "create_task_role" {
  description = "Whether to create a task role"
  type        = bool
  default     = false
}

################################################################################
# Logging and Monitoring
################################################################################

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
  default     = null
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
