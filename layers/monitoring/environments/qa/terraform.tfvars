# Monitoring Layer - QA Environment Configuration
# Version: 2.0 - Enhanced CloudWatch monitoring

aws_region   = "us-east-1"
environment  = "qa"
project_name = "mycompany"

common_tags = {
  Environment = "qa"
  Project     = "mycompany"
  ManagedBy   = "terraform"
  Layer       = "monitoring"
  CostCenter  = "engineering"
}

################################################################################
# SNS Configuration
################################################################################

enable_sns_alerts      = true
enable_critical_alerts = false

alert_email          = "qa-team@example.com"
critical_alert_email = ""

################################################################################
# CloudWatch Logs Configuration
################################################################################

# Log retention - moderate for QA
default_log_retention_days = 14
lambda_log_retention_days  = 7
ecs_log_retention_days     = 14

# Encryption - recommended for QA
enable_log_encryption = true

# Create standard log groups
create_standard_log_groups = true

# Additional application log groups
application_log_groups = {}

################################################################################
# CloudWatch Alarms - QA
################################################################################

create_standard_alarms = false

# Metric alarms for QA testing
metric_alarms = {
  # Monitor ECS service health
  ecs_cpu_high = {
    alarm_name          = "qa-ecs-high-cpu"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 2
    metric_name         = "CPUUtilization"
    namespace           = "AWS/ECS"
    period              = 300
    statistic           = "Average"
    threshold           = 80
    alarm_description   = "ECS CPU utilization is high in QA"
    treat_missing_data  = "notBreaching"
  }
}

composite_alarms = {}
anomaly_detectors = {}

################################################################################
# Log Metric Filters
################################################################################

log_metric_filters = {
  error_count = {
    pattern          = "[time, request_id, level = ERROR*, ...]"
    log_group_name   = "/aws/application/mycompany-qa"
    metric_name      = "ApplicationErrors"
    metric_namespace = "MyApp/QA"
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
    log_group_names = ["/aws/application/mycompany-qa"]
    query_string    = <<-EOT
      fields @timestamp, @message
      | filter @message like /ERROR/
      | sort @timestamp desc
      | limit 50
    EOT
  }
  
  performance_analysis = {
    log_group_names = ["/aws/application/mycompany-qa"]
    query_string    = <<-EOT
      fields @timestamp, @duration
      | filter @duration > 1000
      | stats avg(@duration), max(@duration), min(@duration)
    EOT
  }
}
