################################################################################
# Monitoring Layer - Variables
# Version: 2.0
################################################################################

################################################################################
# General Configuration
################################################################################

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

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

################################################################################
# SNS Configuration
################################################################################

variable "enable_sns_alerts" {
  description = "Enable SNS topic for general alerts"
  type        = bool
  default     = true
}

variable "enable_critical_alerts" {
  description = "Enable separate SNS topic for critical alerts"
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Email address for general alerts"
  type        = string
  default     = ""
}

variable "critical_alert_email" {
  description = "Email address for critical alerts"
  type        = string
  default     = ""
}

################################################################################
# CloudWatch Log Configuration
################################################################################

variable "default_log_retention_days" {
  description = "Default log retention period in days"
  type        = number
  default     = 30
}

variable "lambda_log_retention_days" {
  description = "Log retention for Lambda functions"
  type        = number
  default     = 7
}

variable "ecs_log_retention_days" {
  description = "Log retention for ECS tasks"
  type        = number
  default     = 14
}

variable "enable_log_encryption" {
  description = "Enable KMS encryption for log groups"
  type        = bool
  default     = true
}

variable "create_standard_log_groups" {
  description = "Create standard log groups (application, lambda, ecs)"
  type        = bool
  default     = true
}

variable "application_log_groups" {
  description = "Additional application-specific log groups"
  type = map(object({
    name              = string
    retention_in_days = optional(number)
    kms_key_id        = optional(string)
    skip_destroy      = optional(bool, false)
    tags              = optional(map(string), {})
  }))
  default = {}
}

################################################################################
# CloudWatch Alarms Configuration
################################################################################

variable "create_standard_alarms" {
  description = "Create standard infrastructure alarms"
  type        = bool
  default     = false
}

variable "metric_alarms" {
  description = "Map of CloudWatch metric alarms to create"
  type = map(object({
    alarm_name          = string
    comparison_operator = string
    evaluation_periods  = number
    metric_name         = optional(string)
    namespace           = optional(string)
    period              = optional(number)
    statistic           = optional(string)
    threshold           = optional(number)
    alarm_description   = optional(string)
    alarm_actions       = optional(list(string), [])
    ok_actions          = optional(list(string), [])
    dimensions          = optional(map(string))
    treat_missing_data  = optional(string, "missing")
    tags                = optional(map(string), {})
  }))
  default = {}
}

variable "composite_alarms" {
  description = "Map of CloudWatch composite alarms"
  type = map(object({
    alarm_name        = string
    alarm_rule        = string
    alarm_description = optional(string)
    alarm_actions     = optional(list(string), [])
    ok_actions        = optional(list(string), [])
    tags              = optional(map(string), {})
  }))
  default = {}
}

variable "anomaly_detectors" {
  description = "Map of CloudWatch anomaly detectors"
  type = map(object({
    alarm_name                  = string
    metric_name                 = string
    namespace                   = string
    period                      = number
    stat                        = string
    evaluation_periods          = number
    anomaly_detection_threshold = number
    dimensions                  = optional(map(string))
    alarm_description           = optional(string)
    alarm_actions               = optional(list(string), [])
    tags                        = optional(map(string), {})
  }))
  default = {}
}

################################################################################
# Log Metric Filters
################################################################################

variable "log_metric_filters" {
  description = "Map of log metric filters to create"
  type = map(object({
    pattern          = string
    log_group_name   = string
    metric_name      = string
    metric_namespace = string
    metric_value     = string
    default_value    = optional(number)
    dimensions       = optional(map(string))
    unit             = optional(string)
  }))
  default = {}
}

################################################################################
# CloudWatch Dashboards
################################################################################

variable "dashboards" {
  description = "Map of CloudWatch dashboards to create"
  type = map(object({
    dashboard_name = string
    dashboard_body = string
  }))
  default = {}
}

################################################################################
# CloudWatch Insights Queries
################################################################################

variable "query_definitions" {
  description = "Map of CloudWatch Insights query definitions"
  type = map(object({
    log_group_names = list(string)
    query_string    = string
  }))
  default = {}
}
