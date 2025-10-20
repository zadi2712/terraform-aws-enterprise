################################################################################
# CloudWatch Module - Variables
# Version: 2.0
################################################################################

################################################################################
# Log Groups Configuration
################################################################################

variable "log_groups" {
  description = "Map of CloudWatch log groups to create"
  type = map(object({
    name              = string
    retention_in_days = optional(number)
    kms_key_id        = optional(string)
    skip_destroy      = optional(bool, false)
    tags              = optional(map(string), {})
  }))
  default = {}
}

variable "default_log_retention_days" {
  description = "Default retention period for log groups (days)"
  type        = number
  default     = 30
  
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.default_log_retention_days)
    error_message = "Retention days must be a valid CloudWatch Logs retention period"
  }
}

variable "default_kms_key_id" {
  description = "Default KMS key ID for log group encryption"
  type        = string
  default     = null
}

################################################################################
# Log Streams Configuration
################################################################################

variable "log_streams" {
  description = "Map of CloudWatch log streams to create"
  type = map(object({
    name           = string
    log_group_name = string
  }))
  default = {}
}

################################################################################
# Log Metric Filters Configuration
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
# Metric Alarms Configuration
################################################################################

variable "metric_alarms" {
  description = "Map of CloudWatch metric alarms to create"
  type = map(object({
    alarm_name          = string
    comparison_operator = string
    evaluation_periods  = number
    
    # Metric queries (for complex expressions)
    metric_queries = optional(list(object({
      id          = string
      expression  = optional(string)
      label       = optional(string)
      return_data = optional(bool)
      metric = optional(object({
        metric_name = string
        namespace   = string
        period      = number
        stat        = string
        unit        = optional(string)
        dimensions  = optional(map(string))
      }))
    })), [])
    
    # Standard metric configuration
    metric_name        = optional(string)
    namespace          = optional(string)
    period             = optional(number)
    statistic          = optional(string)
    extended_statistic = optional(string)
    dimensions         = optional(map(string))
    
    # Threshold
    threshold           = optional(number)
    threshold_metric_id = optional(string)
    
    # Actions
    alarm_actions             = optional(list(string), [])
    ok_actions                = optional(list(string), [])
    insufficient_data_actions = optional(list(string), [])
    
    # Configuration
    alarm_description         = optional(string)
    datapoints_to_alarm       = optional(number)
    treat_missing_data        = optional(string, "missing")
    evaluate_low_sample_count_percentiles = optional(string)
    
    # Tags
    tags = optional(map(string), {})
  }))
  default = {}
}

################################################################################
# Composite Alarms Configuration
################################################################################

variable "composite_alarms" {
  description = "Map of CloudWatch composite alarms to create"
  type = map(object({
    alarm_name          = string
    alarm_rule          = string
    alarm_description   = optional(string)
    actions_enabled     = optional(bool, true)
    alarm_actions       = optional(list(string), [])
    ok_actions          = optional(list(string), [])
    insufficient_data_actions = optional(list(string), [])
    tags                = optional(map(string), {})
  }))
  default = {}
}

################################################################################
# Dashboards Configuration
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
# Query Definitions Configuration
################################################################################

variable "query_definitions" {
  description = "Map of CloudWatch Insights query definitions"
  type = map(object({
    log_group_names = list(string)
    query_string    = string
  }))
  default = {}
}

################################################################################
# Anomaly Detection Configuration
################################################################################

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
# Log Resource Policies Configuration
################################################################################

variable "log_resource_policies" {
  description = "Map of CloudWatch Logs resource policies"
  type = map(object({
    policy_document = string
  }))
  default = {}
}

################################################################################
# Log Data Protection Policies Configuration
################################################################################

variable "log_data_protection_policies" {
  description = "Map of CloudWatch Logs data protection policies"
  type = map(object({
    log_group_name  = string
    policy_document = string
  }))
  default = {}
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
