# Monitoring Layer - Development Environment Configuration
# Version: 2.0 - Enhanced CloudWatch monitoring

aws_region   = "us-east-1"
environment  = "dev"
project_name = "mycompany"

common_tags = {
  Environment = "dev"
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

# Alert emails (update with your email addresses)
alert_email          = "devteam@example.com"
critical_alert_email = ""

################################################################################
# CloudWatch Logs Configuration
################################################################################

# Log retention - shorter for dev to save costs
default_log_retention_days = 7
lambda_log_retention_days  = 3
ecs_log_retention_days     = 7

# Encryption - optional in dev
enable_log_encryption = false

# Create standard log groups
create_standard_log_groups = true

# Additional application log groups
application_log_groups = {
  # Example: Add your application-specific log groups
  # api = {
  #   name              = "/aws/application/api-dev"
  #   retention_in_days = 7
  # }
}

################################################################################
# CloudWatch Alarms - Development
################################################################################

create_standard_alarms = false

# Custom metric alarms
metric_alarms = {
  # Example: High Lambda error rate
  # lambda_errors = {
  #   alarm_name          = "dev-lambda-high-errors"
  #   comparison_operator = "GreaterThanThreshold"
  #   evaluation_periods  = 1
  #   metric_name         = "Errors"
  #   namespace           = "AWS/Lambda"
  #   period              = 300
  #   statistic           = "Sum"
  #   threshold           = 10
  #   alarm_description   = "Lambda function error rate is high"
  #   treat_missing_data  = "notBreaching"
  # }
}

# Composite alarms
composite_alarms = {}

# Anomaly detectors - disabled in dev to save costs
anomaly_detectors = {}

################################################################################
# Log Metric Filters
################################################################################

log_metric_filters = {
  # Example: Track application errors
  # app_errors = {
  #   pattern          = "[time, request_id, level = ERROR*, ...]"
  #   log_group_name   = "/aws/application/mycompany-dev"
  #   metric_name      = "ApplicationErrors"
  #   metric_namespace = "MyApp/Dev"
  #   metric_value     = "1"
  #   default_value    = 0
  # }
}

################################################################################
# CloudWatch Dashboards
################################################################################

dashboards = {
  # Example: Development overview dashboard
  # overview = {
  #   dashboard_name = "dev-overview"
  #   dashboard_body = file("${path.module}/dashboards/dev-overview.json")
  # }
}

################################################################################
# CloudWatch Insights Queries
################################################################################

query_definitions = {
  # Predefined query for error analysis
  error_analysis = {
    log_group_names = ["/aws/application/mycompany-dev"]
    query_string    = <<-EOT
      fields @timestamp, @message
      | filter @message like /ERROR/
      | sort @timestamp desc
      | limit 20
    EOT
  }
}
