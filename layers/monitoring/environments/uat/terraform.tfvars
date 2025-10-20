# Monitoring Layer - UAT Environment Configuration
# Version: 2.0 - Enhanced CloudWatch monitoring

aws_region   = "us-east-1"
environment  = "uat"
project_name = "mycompany"

common_tags = {
  Environment = "uat"
  Project     = "mycompany"
  ManagedBy   = "terraform"
  Layer       = "monitoring"
  CostCenter  = "engineering"
}

################################################################################
# SNS Configuration
################################################################################

enable_sns_alerts      = true
enable_critical_alerts = true

alert_email          = "uat-team@example.com"
critical_alert_email = "platform-oncall@example.com"

################################################################################
# CloudWatch Logs Configuration
################################################################################

# Log retention - production-like for UAT
default_log_retention_days = 30
lambda_log_retention_days  = 14
ecs_log_retention_days     = 30

# Encryption - enabled for UAT
enable_log_encryption = true

# Create standard log groups
create_standard_log_groups = true

# Additional application log groups
application_log_groups = {
  # Example application logs
  api = {
    name              = "/aws/application/api-uat"
    retention_in_days = 30
  }
}

################################################################################
# CloudWatch Alarms - UAT (Production-like)
################################################################################

create_standard_alarms = true

# Production-like metric alarms
metric_alarms = {
  ecs_cpu_high = {
    alarm_name          = "uat-ecs-high-cpu"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 2
    metric_name         = "CPUUtilization"
    namespace           = "AWS/ECS"
    period              = 300
    statistic           = "Average"
    threshold           = 75
    alarm_description   = "ECS CPU utilization is high"
    treat_missing_data  = "notBreaching"
  }
  
  ecs_memory_high = {
    alarm_name          = "uat-ecs-high-memory"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 2
    metric_name         = "MemoryUtilization"
    namespace           = "AWS/ECS"
    period              = 300
    statistic           = "Average"
    threshold           = 80
    alarm_description   = "ECS memory utilization is high"
  }
  
  alb_target_health = {
    alarm_name          = "uat-alb-unhealthy-targets"
    comparison_operator = "LessThanThreshold"
    evaluation_periods  = 2
    metric_name         = "HealthyHostCount"
    namespace           = "AWS/ApplicationELB"
    period              = 60
    statistic           = "Average"
    threshold           = 1
    alarm_description   = "ALB has unhealthy targets"
  }
}

# Composite alarms
composite_alarms = {
  system_critical = {
    alarm_name        = "uat-system-critical"
    alarm_description = "Multiple critical metrics triggered"
    alarm_rule        = "ALARM(uat-ecs-high-cpu) AND ALARM(uat-ecs-high-memory)"
  }
}

# Anomaly detectors
anomaly_detectors = {}

################################################################################
# Log Metric Filters
################################################################################

log_metric_filters = {
  error_count = {
    pattern          = "[time, request_id, level = ERROR*, ...]"
    log_group_name   = "/aws/application/mycompany-uat"
    metric_name      = "ApplicationErrors"
    metric_namespace = "MyApp/UAT"
    metric_value     = "1"
    default_value    = 0
  }
  
  warning_count = {
    pattern          = "[time, request_id, level = WARN*, ...]"
    log_group_name   = "/aws/application/mycompany-uat"
    metric_name      = "ApplicationWarnings"
    metric_namespace = "MyApp/UAT"
    metric_value     = "1"
    default_value    = 0
  }
}

################################################################################
# CloudWatch Dashboards
################################################################################

dashboards = {}

################################################################################
# CloudWatch Insights Queries
################################################################################

query_definitions = {
  error_analysis = {
    log_group_names = ["/aws/application/mycompany-uat"]
    query_string    = <<-EOT
      fields @timestamp, @message
      | filter @message like /ERROR/
      | sort @timestamp desc
      | limit 100
    EOT
  }
  
  request_latency = {
    log_group_names = ["/aws/application/mycompany-uat"]
    query_string    = <<-EOT
      fields @timestamp, @duration
      | stats avg(@duration), max(@duration), pct(@duration, 95)
      by bin(5m)
    EOT
  }
}
