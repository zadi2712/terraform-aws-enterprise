variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "create_rds" {
  description = "Create RDS instance"
  type        = bool
  default     = true
}

variable "rds_engine_version" {
  description = "RDS engine version"
  type        = string
  default     = "15.4"
}

variable "rds_instance_type" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.small"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "Max allocated storage"
  type        = number
  default     = 100
}

variable "database_name" {
  description = "Database name"
  type        = string
  default     = "appdb"
}

variable "master_username" {
  description = "Master username"
  type        = string
  default     = "dbadmin"
}

variable "master_password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

variable "enable_multi_az" {
  description = "Enable Multi-AZ"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Backup retention in days"
  type        = number
  default     = 7
}

variable "enable_performance_insights" {
  description = "Enable Performance Insights"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
