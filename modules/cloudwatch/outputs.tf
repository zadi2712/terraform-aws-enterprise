################################################################################
# CloudWatch Module - Outputs
# Version: 2.0
################################################################################

################################################################################
# Log Group Outputs
################################################################################

output "log_group_names" {
  description = "Map of log group names"
  value       = { for k, v in aws_cloudwatch_log_group.this : k => v.name }
}

output "log_group_arns" {
  description = "Map of log group ARNs"
  value       = { for k, v in aws_cloudwatch_log_group.this : k => v.arn }
}

output "log_groups" {
  description = "Complete log group information"
  value = {
    for k, v in aws_cloudwatch_log_group.this : k => {
      name              = v.name
      arn               = v.arn
      retention_in_days = v.retention_in_days
      kms_key_id        = v.kms_key_id
    }
  }
}

################################################################################
# Log Stream Outputs
################################################################################

output "log_stream_names" {
  description = "Map of log stream names"
  value       = { for k, v in aws_cloudwatch_log_stream.this : k => v.name }
}

output "log_stream_arns" {
  description = "Map of log stream ARNs"
  value       = { for k, v in aws_cloudwatch_log_stream.this : k => v.arn }
}

################################################################################
# Metric Filter Outputs
################################################################################

output "log_metric_filter_names" {
  description = "Map of log metric filter names"
  value       = { for k, v in aws_cloudwatch_log_metric_filter.this : k => v.name }
}

output "log_metric_filters" {
  description = "Complete log metric filter information"
  value = {
    for k, v in aws_cloudwatch_log_metric_filter.this : k => {
      name           = v.name
      pattern        = v.pattern
      log_group_name = v.log_group_name
    }
  }
}

################################################################################
# Metric Alarm Outputs
################################################################################

output "metric_alarm_names" {
  description = "Map of metric alarm names"
  value       = { for k, v in aws_cloudwatch_metric_alarm.this : k => v.alarm_name }
}

output "metric_alarm_arns" {
  description = "Map of metric alarm ARNs"
  value       = { for k, v in aws_cloudwatch_metric_alarm.this : k => v.arn }
}

output "metric_alarms" {
  description = "Complete metric alarm information"
  value = {
    for k, v in aws_cloudwatch_metric_alarm.this : k => {
      alarm_name = v.alarm_name
      arn        = v.arn
      id         = v.id
    }
  }
}

################################################################################
# Composite Alarm Outputs
################################################################################

output "composite_alarm_names" {
  description = "Map of composite alarm names"
  value       = { for k, v in aws_cloudwatch_composite_alarm.this : k => v.alarm_name }
}

output "composite_alarm_arns" {
  description = "Map of composite alarm ARNs"
  value       = { for k, v in aws_cloudwatch_composite_alarm.this : k => v.arn }
}

################################################################################
# Dashboard Outputs
################################################################################

output "dashboard_names" {
  description = "Map of dashboard names"
  value       = { for k, v in aws_cloudwatch_dashboard.this : k => v.dashboard_name }
}

output "dashboard_arns" {
  description = "Map of dashboard ARNs"
  value       = { for k, v in aws_cloudwatch_dashboard.this : k => v.dashboard_arn }
}

################################################################################
# Query Definition Outputs
################################################################################

output "query_definition_ids" {
  description = "Map of query definition IDs"
  value       = { for k, v in aws_cloudwatch_query_definition.this : k => v.query_definition_id }
}

################################################################################
# Anomaly Detector Outputs
################################################################################

output "anomaly_detector_alarm_names" {
  description = "Map of anomaly detector alarm names"
  value       = { for k, v in aws_cloudwatch_metric_alarm.anomaly : k => v.alarm_name }
}

output "anomaly_detector_alarm_arns" {
  description = "Map of anomaly detector alarm ARNs"
  value       = { for k, v in aws_cloudwatch_metric_alarm.anomaly : k => v.arn }
}

################################################################################
# Summary Outputs
################################################################################

output "monitoring_summary" {
  description = "Summary of all CloudWatch monitoring resources"
  value = {
    log_groups_count       = length(aws_cloudwatch_log_group.this)
    log_streams_count      = length(aws_cloudwatch_log_stream.this)
    metric_filters_count   = length(aws_cloudwatch_log_metric_filter.this)
    metric_alarms_count    = length(aws_cloudwatch_metric_alarm.this)
    composite_alarms_count = length(aws_cloudwatch_composite_alarm.this)
    dashboards_count       = length(aws_cloudwatch_dashboard.this)
    query_definitions_count = length(aws_cloudwatch_query_definition.this)
    anomaly_detectors_count = length(aws_cloudwatch_metric_alarm.anomaly)
  }
}
