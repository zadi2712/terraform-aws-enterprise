################################################################################
# Monitoring Layer - Outputs
# Version: 2.0
################################################################################

################################################################################
# SNS Outputs
################################################################################

output "sns_alerts_topic_arn" {
  description = "SNS topic ARN for general alerts"
  value       = var.enable_sns_alerts ? module.sns_alerts[0].topic_arn : null
}

output "sns_alerts_topic_name" {
  description = "SNS topic name for general alerts"
  value       = var.enable_sns_alerts ? module.sns_alerts[0].topic_name : null
}

output "sns_critical_topic_arn" {
  description = "SNS topic ARN for critical alerts"
  value       = var.enable_critical_alerts ? module.sns_critical[0].topic_arn : null
}

output "sns_critical_topic_name" {
  description = "SNS topic name for critical alerts"
  value       = var.enable_critical_alerts ? module.sns_critical[0].topic_name : null
}

################################################################################
# CloudWatch Log Groups Outputs
################################################################################

output "log_group_names" {
  description = "Map of CloudWatch log group names"
  value       = module.cloudwatch.log_group_names
}

output "log_group_arns" {
  description = "Map of CloudWatch log group ARNs"
  value       = module.cloudwatch.log_group_arns
}

output "log_groups" {
  description = "Complete log group information"
  value       = module.cloudwatch.log_groups
}

################################################################################
# CloudWatch Alarms Outputs
################################################################################

output "metric_alarm_names" {
  description = "Map of metric alarm names"
  value       = module.cloudwatch.metric_alarm_names
}

output "metric_alarm_arns" {
  description = "Map of metric alarm ARNs"
  value       = module.cloudwatch.metric_alarm_arns
}

output "composite_alarm_names" {
  description = "Map of composite alarm names"
  value       = module.cloudwatch.composite_alarm_names
}

output "composite_alarm_arns" {
  description = "Map of composite alarm ARNs"
  value       = module.cloudwatch.composite_alarm_arns
}

################################################################################
# CloudWatch Dashboards Outputs
################################################################################

output "dashboard_names" {
  description = "Map of dashboard names"
  value       = module.cloudwatch.dashboard_names
}

output "dashboard_arns" {
  description = "Map of dashboard ARNs"
  value       = module.cloudwatch.dashboard_arns
}

################################################################################
# CloudWatch Query Definitions Outputs
################################################################################

output "query_definition_ids" {
  description = "Map of query definition IDs"
  value       = module.cloudwatch.query_definition_ids
}

################################################################################
# Monitoring Summary
################################################################################

output "monitoring_summary" {
  description = "Summary of all monitoring resources"
  value       = module.cloudwatch.monitoring_summary
}

output "monitoring_endpoints" {
  description = "Important monitoring endpoints and ARNs"
  value = {
    sns = {
      alerts_topic   = var.enable_sns_alerts ? module.sns_alerts[0].topic_arn : null
      critical_topic = var.enable_critical_alerts ? module.sns_critical[0].topic_arn : null
    }
    cloudwatch = {
      log_groups_count = module.cloudwatch.monitoring_summary.log_groups_count
      alarms_count     = module.cloudwatch.monitoring_summary.metric_alarms_count
      dashboards_count = module.cloudwatch.monitoring_summary.dashboards_count
    }
  }
}
