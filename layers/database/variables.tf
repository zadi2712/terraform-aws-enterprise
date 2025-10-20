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

################################################################################
# Enhanced RDS Configuration
################################################################################

variable "rds_engine" {
  description = "RDS engine type"
  type        = string
  default     = "postgres"
}

variable "rds_storage_type" {
  description = "RDS storage type (gp2, gp3, io1, io2)"
  type        = string
  default     = "gp3"
}

variable "rds_iops" {
  description = "IOPS for provisioned IOPS storage"
  type        = number
  default     = null
}

variable "rds_storage_throughput" {
  description = "Storage throughput for gp3 (MiB/s)"
  type        = number
  default     = null
}

variable "rds_publicly_accessible" {
  description = "Make RDS instance publicly accessible"
  type        = bool
  default     = false
}

variable "rds_backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "rds_maintenance_window" {
  description = "Preferred maintenance window (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "rds_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = []
}

variable "rds_monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0, 1, 5, 10, 15, 30, 60)"
  type        = number
  default     = 0
}

variable "rds_performance_insights_retention_period" {
  description = "Performance Insights retention period in days"
  type        = number
  default     = 7
}

variable "rds_auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades"
  type        = bool
  default     = true
}

variable "rds_allow_major_version_upgrade" {
  description = "Allow major version upgrades"
  type        = bool
  default     = false
}

variable "rds_apply_immediately" {
  description = "Apply changes immediately (vs maintenance window)"
  type        = bool
  default     = false
}

variable "rds_enable_blue_green_update" {
  description = "Enable blue/green deployments for updates"
  type        = bool
  default     = false
}

variable "rds_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "rds_skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = false
}

variable "rds_iam_authentication_enabled" {
  description = "Enable IAM database authentication"
  type        = bool
  default     = false
}

variable "rds_manage_master_password" {
  description = "Let RDS manage master password in Secrets Manager"
  type        = bool
  default     = false
}

variable "rds_store_password_in_secrets_manager" {
  description = "Store master password in Secrets Manager (manual)"
  type        = bool
  default     = false
}

variable "rds_create_parameter_group" {
  description = "Create custom parameter group"
  type        = bool
  default     = false
}

variable "rds_parameter_group_family" {
  description = "Parameter group family"
  type        = string
  default     = ""
}

variable "rds_parameters" {
  description = "Database parameters"
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "immediate")
  }))
  default = []
}

variable "rds_create_option_group" {
  description = "Create custom option group"
  type        = bool
  default     = false
}

variable "rds_major_engine_version" {
  description = "Major engine version for option group"
  type        = string
  default     = ""
}

variable "rds_options" {
  description = "Database options"
  type = list(object({
    option_name     = string
    option_settings = optional(list(object({
      name  = string
      value = string
    })), [])
  }))
  default = []
}

variable "rds_read_replicas" {
  description = "Map of read replicas to create"
  type = map(object({
    instance_class               = optional(string)
    max_allocated_storage        = optional(number)
    storage_type                 = optional(string)
    iops                         = optional(number)
    multi_az                     = optional(bool, false)
    availability_zone            = optional(string)
    monitoring_interval          = optional(number)
    performance_insights_enabled = optional(bool)
    auto_minor_version_upgrade   = optional(bool)
    tags                         = optional(map(string), {})
  }))
  default = {}
}
