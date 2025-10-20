################################################################################
# RDS Module - Variables
# Version: 2.0
################################################################################

################################################################################
# Required Variables
################################################################################

variable "identifier" {
  description = "Database instance identifier"
  type        = string
}

variable "engine" {
  description = "Database engine (postgres, mysql, mariadb, oracle-ee, sqlserver-ee)"
  type        = string
  
  validation {
    condition = contains([
      "postgres", "mysql", "mariadb",
      "oracle-ee", "oracle-se2",
      "sqlserver-ee", "sqlserver-se", "sqlserver-ex", "sqlserver-web"
    ], var.engine)
    error_message = "Invalid database engine"
  }
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
}

variable "instance_class" {
  description = "Instance class (e.g., db.t3.micro, db.r5.large)"
  type        = string
}

################################################################################
# Storage Configuration
################################################################################

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
}

variable "max_allocated_storage" {
  description = "Maximum storage for autoscaling (0 to disable)"
  type        = number
  default     = null
}

variable "storage_type" {
  description = "Storage type (gp2, gp3, io1, io2)"
  type        = string
  default     = "gp3"
}

variable "iops" {
  description = "IOPS for io1/io2/gp3 storage"
  type        = number
  default     = null
}

variable "storage_throughput" {
  description = "Storage throughput for gp3 (MiB/s)"
  type        = number
  default     = null
}

variable "storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ARN for storage encryption"
  type        = string
  default     = null
}

################################################################################
# Database Configuration
################################################################################

variable "database_name" {
  description = "Initial database name"
  type        = string
  default     = null
}

variable "master_username" {
  description = "Master username"
  type        = string
}

variable "master_password" {
  description = "Master password (ignored if manage_master_user_password is true)"
  type        = string
  sensitive   = true
  default     = null
}

variable "manage_master_user_password" {
  description = "Let RDS manage master password in Secrets Manager"
  type        = bool
  default     = false
}

variable "master_user_secret_kms_key_id" {
  description = "KMS key for RDS-managed master password secret"
  type        = string
  default     = null
}

variable "port" {
  description = "Database port (defaults based on engine)"
  type        = number
  default     = null
}

variable "character_set_name" {
  description = "Character set for Oracle/SQL Server"
  type        = string
  default     = null
}

################################################################################
# Network Configuration
################################################################################

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "availability_zone" {
  description = "Availability zone (for single-AZ deployment)"
  type        = string
  default     = null
}

variable "db_subnet_group_name" {
  description = "DB subnet group name (if not creating one)"
  type        = string
  default     = null
}

variable "create_db_subnet_group" {
  description = "Whether to create DB subnet group"
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "List of subnet IDs for DB subnet group"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "List of VPC security group IDs"
  type        = list(string)
  default     = []
}

variable "publicly_accessible" {
  description = "Make instance publicly accessible"
  type        = bool
  default     = false
}

variable "network_type" {
  description = "Network type (IPV4 or DUAL)"
  type        = string
  default     = "IPV4"
}

################################################################################
# Parameter and Option Groups
################################################################################

variable "create_parameter_group" {
  description = "Whether to create custom parameter group"
  type        = bool
  default     = false
}

variable "parameter_group_name" {
  description = "Name of existing parameter group to use"
  type        = string
  default     = null
}

variable "parameter_group_family" {
  description = "Parameter group family (e.g., postgres15, mysql8.0)"
  type        = string
  default     = ""
}

variable "parameters" {
  description = "List of database parameters"
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "immediate")
  }))
  default = []
}

variable "create_option_group" {
  description = "Whether to create custom option group"
  type        = bool
  default     = false
}

variable "option_group_name" {
  description = "Name of existing option group to use"
  type        = string
  default     = null
}

variable "major_engine_version" {
  description = "Major engine version for option group"
  type        = string
  default     = ""
}

variable "options" {
  description = "List of database options"
  type = list(object({
    option_name     = string
    option_settings = optional(list(object({
      name  = string
      value = string
    })), [])
  }))
  default = []
}

################################################################################
# Backup Configuration
################################################################################

variable "backup_retention_period" {
  description = "Backup retention period in days (0-35)"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "Backup retention must be between 0 and 35 days"
  }
}

variable "backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "copy_tags_to_snapshot" {
  description = "Copy tags to snapshots"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = false
}

variable "final_snapshot_identifier" {
  description = "Final snapshot identifier (auto-generated if null)"
  type        = string
  default     = null
}

################################################################################
# Monitoring Configuration
################################################################################

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = []
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0, 1, 5, 10, 15, 30, 60)"
  type        = number
  default     = 0
  
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be 0, 1, 5, 10, 15, 30, or 60 seconds"
  }
}

variable "create_monitoring_role" {
  description = "Create IAM role for enhanced monitoring"
  type        = bool
  default     = true
}

variable "monitoring_role_arn" {
  description = "ARN of existing monitoring role"
  type        = string
  default     = null
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = false
}

variable "performance_insights_kms_key_id" {
  description = "KMS key for Performance Insights encryption"
  type        = string
  default     = null
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention period (days)"
  type        = number
  default     = 7
}

################################################################################
# Upgrade and Maintenance
################################################################################

variable "auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades"
  type        = bool
  default     = true
}

variable "allow_major_version_upgrade" {
  description = "Allow major version upgrades"
  type        = bool
  default     = false
}

variable "apply_immediately" {
  description = "Apply changes immediately (vs during maintenance window)"
  type        = bool
  default     = false
}

variable "enable_blue_green_update" {
  description = "Enable blue/green deployment for updates"
  type        = bool
  default     = false
}

################################################################################
# Security Configuration
################################################################################

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "iam_database_authentication_enabled" {
  description = "Enable IAM database authentication"
  type        = bool
  default     = false
}

variable "ca_cert_identifier" {
  description = "CA certificate identifier"
  type        = string
  default     = null
}

variable "license_model" {
  description = "License model (for Oracle/SQL Server)"
  type        = string
  default     = null
}

################################################################################
# Domain Join (SQL Server)
################################################################################

variable "domain" {
  description = "Active Directory domain to join"
  type        = string
  default     = null
}

variable "domain_iam_role_name" {
  description = "IAM role name for domain join"
  type        = string
  default     = null
}

################################################################################
# Read Replicas
################################################################################

variable "read_replicas" {
  description = "Map of read replicas to create"
  type = map(object({
    instance_class                = optional(string)
    max_allocated_storage         = optional(number)
    storage_type                  = optional(string)
    iops                          = optional(number)
    multi_az                      = optional(bool, false)
    availability_zone             = optional(string)
    monitoring_interval           = optional(number)
    performance_insights_enabled  = optional(bool)
    auto_minor_version_upgrade    = optional(bool)
    apply_immediately             = optional(bool, false)
    publicly_accessible           = optional(bool, false)
    vpc_security_group_ids        = optional(list(string))
    skip_final_snapshot           = optional(bool, true)
    tags                          = optional(map(string), {})
  }))
  default = {}
}

################################################################################
# Secrets Manager Integration
################################################################################

variable "store_master_password_in_secrets_manager" {
  description = "Store master password in Secrets Manager"
  type        = bool
  default     = false
}

variable "secrets_manager_kms_key_id" {
  description = "KMS key for Secrets Manager secret encryption"
  type        = string
  default     = null
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
