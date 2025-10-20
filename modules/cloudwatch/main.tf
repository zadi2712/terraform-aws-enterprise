################################################################################
# CloudWatch Module - Enterprise Monitoring and Logging
# Version: 2.0
# Description: Comprehensive CloudWatch monitoring with log groups, alarms, and dashboards
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  common_tags = merge(
    var.tags,
    {
      Module    = "cloudwatch"
      ManagedBy = "terraform"
    }
  )
}

################################################################################
# CloudWatch Log Groups
################################################################################

resource "aws_cloudwatch_log_group" "this" {
  for_each = var.log_groups

  name              = each.value.name
  retention_in_days = lookup(each.value, "retention_in_days", var.default_log_retention_days)
  kms_key_id        = lookup(each.value, "kms_key_id", var.default_kms_key_id)
  
  skip_destroy = lookup(each.value, "skip_destroy", false)

  tags = merge(
    local.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = each.value.name
    }
  )
}

################################################################################
# CloudWatch Log Streams
################################################################################

resource "aws_cloudwatch_log_stream" "this" {
  for_each = var.log_streams

  name           = each.value.name
  log_group_name = each.value.log_group_name

  depends_on = [aws_cloudwatch_log_group.this]
}

################################################################################
# CloudWatch Log Metric Filters
################################################################################

resource "aws_cloudwatch_log_metric_filter" "this" {
  for_each = var.log_metric_filters

  name           = each.key
  pattern        = each.value.pattern
  log_group_name = each.value.log_group_name

  metric_transformation {
    name          = each.value.metric_name
    namespace     = each.value.metric_namespace
    value         = each.value.metric_value
    default_value = lookup(each.value, "default_value", null)
    dimensions    = lookup(each.value, "dimensions", null)
    unit          = lookup(each.value, "unit", null)
  }

  depends_on = [aws_cloudwatch_log_group.this]
}

################################################################################
# CloudWatch Metric Alarms
################################################################################

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = var.metric_alarms

  alarm_name          = each.value.alarm_name
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  
  # Metric query or standard metric
  dynamic "metric_query" {
    for_each = lookup(each.value, "metric_queries", [])
    
    content {
      id          = metric_query.value.id
      expression  = lookup(metric_query.value, "expression", null)
      label       = lookup(metric_query.value, "label", null)
      return_data = lookup(metric_query.value, "return_data", null)
      
      dynamic "metric" {
        for_each = lookup(metric_query.value, "metric", null) != null ? [metric_query.value.metric] : []
        
        content {
          metric_name = metric.value.metric_name
          namespace   = metric.value.namespace
          period      = metric.value.period
          stat        = metric.value.stat
          unit        = lookup(metric.value, "unit", null)
          dimensions  = lookup(metric.value, "dimensions", null)
        }
      }
    }
  }

  # Standard metric configuration
  metric_name        = lookup(each.value, "metric_name", null)
  namespace          = lookup(each.value, "namespace", null)
  period             = lookup(each.value, "period", null)
  statistic          = lookup(each.value, "statistic", null)
  extended_statistic = lookup(each.value, "extended_statistic", null)
  
  # Threshold
  threshold                 = lookup(each.value, "threshold", null)
  threshold_metric_id       = lookup(each.value, "threshold_metric_id", null)
  
  # Actions
  alarm_actions             = lookup(each.value, "alarm_actions", [])
  ok_actions                = lookup(each.value, "ok_actions", [])
  insufficient_data_actions = lookup(each.value, "insufficient_data_actions", [])
  
  # Configuration
  alarm_description         = lookup(each.value, "alarm_description", "")
  datapoints_to_alarm       = lookup(each.value, "datapoints_to_alarm", null)
  treat_missing_data        = lookup(each.value, "treat_missing_data", "missing")
  evaluate_low_sample_count_percentiles = lookup(each.value, "evaluate_low_sample_count_percentiles", null)
  
  # Dimensions
  dimensions = lookup(each.value, "dimensions", null)
  
  # Anomaly detection
  dynamic "metric" {
    for_each = lookup(each.value, "anomaly_detection", null) != null ? [each.value.anomaly_detection] : []
    
    content {
      metric_name = metric.value.metric_name
      namespace   = metric.value.namespace
      period      = metric.value.period
      stat        = metric.value.stat
      dimensions  = lookup(metric.value, "dimensions", null)
    }
  }

  tags = merge(
    local.common_tags,
    lookup(each.value, "tags", {})
  )
}

################################################################################
# CloudWatch Composite Alarms
################################################################################

resource "aws_cloudwatch_composite_alarm" "this" {
  for_each = var.composite_alarms

  alarm_name          = each.value.alarm_name
  alarm_description   = lookup(each.value, "alarm_description", "")
  actions_enabled     = lookup(each.value, "actions_enabled", true)
  alarm_actions       = lookup(each.value, "alarm_actions", [])
  ok_actions          = lookup(each.value, "ok_actions", [])
  insufficient_data_actions = lookup(each.value, "insufficient_data_actions", [])
  
  alarm_rule = each.value.alarm_rule

  tags = merge(
    local.common_tags,
    lookup(each.value, "tags", {})
  )

  depends_on = [aws_cloudwatch_metric_alarm.this]
}

################################################################################
# CloudWatch Dashboards
################################################################################

resource "aws_cloudwatch_dashboard" "this" {
  for_each = var.dashboards

  dashboard_name = each.value.dashboard_name
  dashboard_body = each.value.dashboard_body
}

################################################################################
# CloudWatch Query Definitions
################################################################################

resource "aws_cloudwatch_query_definition" "this" {
  for_each = var.query_definitions

  name = each.key

  log_group_names = each.value.log_group_names
  query_string    = each.value.query_string
}

################################################################################
# CloudWatch Anomaly Detector
################################################################################

resource "aws_cloudwatch_metric_alarm" "anomaly" {
  for_each = var.anomaly_detectors

  alarm_name          = each.value.alarm_name
  comparison_operator = "LessThanLowerOrGreaterThanUpperThreshold"
  evaluation_periods  = each.value.evaluation_periods
  threshold_metric_id = "ad1"
  
  alarm_description = lookup(each.value, "alarm_description", "Anomaly detection alarm")
  alarm_actions     = lookup(each.value, "alarm_actions", [])

  metric_query {
    id          = "m1"
    return_data = true
    
    metric {
      metric_name = each.value.metric_name
      namespace   = each.value.namespace
      period      = each.value.period
      stat        = each.value.stat
      dimensions  = lookup(each.value, "dimensions", null)
    }
  }

  metric_query {
    id         = "ad1"
    expression = "ANOMALY_DETECTION_BAND(m1, ${each.value.anomaly_detection_threshold})"
    label      = "Anomaly Detection Band"
  }

  tags = merge(
    local.common_tags,
    lookup(each.value, "tags", {})
  )
}

################################################################################
# CloudWatch Log Resource Policy (for service integration)
################################################################################

resource "aws_cloudwatch_log_resource_policy" "this" {
  for_each = var.log_resource_policies

  policy_name     = each.key
  policy_document = each.value.policy_document
}

################################################################################
# CloudWatch Log Data Protection Policy
################################################################################

resource "aws_cloudwatch_log_data_protection_policy" "this" {
  for_each = var.log_data_protection_policies

  log_group_name  = each.value.log_group_name
  policy_document = each.value.policy_document

  depends_on = [aws_cloudwatch_log_group.this]
}
