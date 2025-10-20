# Monitoring Layer - Production Environment Configuration
# Version: 2.0 - Enhanced CloudWatch monitoring

aws_region   = "us-east-1"
environment  = "prod"
project_name = "mycompany"

common_tags = {
  Environment = "prod"
  Project     = "mycompany"
  ManagedBy   = "terraform"
  Layer       = "monitoring"
  CostCenter  = "engineering"
  Compliance  = "required"
}

################################################################################
# SNS Configuration - Production
################################################################################

enable_sns_alerts      = true
enable_critical_alerts = true

# Production alert emails (update with actual email addresses)
alert_email          = "platform-team@example.com"
critical_alert_email = "oncall@example.com"

################################################################################
# CloudWatch Logs Configuration - Production
################################################################################

# Log retention - compliance-driven for production
default_log_retention_days = 90
lambda_log_retention_days  = 30
ecs_log_retention_days     = 60

# Encryption - mandatory for production
enable_log_encryption = true

# Create standard log groups
create_standard_log_groups = true

# Additional application log groups
application_log_groups = {
  api = {
    name              = "/aws/application/api-prod"
    retention_in_days = 90
  }
  
  worker = {
    name              = "/aws/application/worker-prod"
    retention_in_days = 60
  }
}

################################################################################
# CloudWatch Alarms - Production
################################################################################

create_standard_alarms = true

# Comprehensive metric alarms for production
metric_alarms = {
  # ECS Monitoring
  ecs_cpu_high = {
    alarm_name          = "prod-ecs-high-cpu"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 3
    metric_name         = "CPUUtilization"
    namespace           = "AWS/ECS"
    period              = 300
    statistic           = "Average"
    threshold           = 70
    datapoints_to_alarm = 2
    alarm_description   = "ECS CPU utilization exceeds 70%"
    treat_missing_data  = "notBreaching"
  }
  
  ecs_memory_high = {
    alarm_name          = "prod-ecs-high-memory"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 3
    metric_name         = "MemoryUtilization"
    namespace           = "AWS/ECS"
    period              = 300
    statistic           = "Average"
    threshold           = 80
    datapoints_to_alarm = 2
    alarm_description   = "ECS memory utilization exceeds 80%"
  }
  
  # ALB Monitoring
  alb_target_health = {
    alarm_name          = "prod-alb-unhealthy-targets"
    comparison_operator = "LessThanThreshold"
    evaluation_periods  = 2
    metric_name         = "HealthyHostCount"
    namespace           = "AWS/ApplicationELB"
    period              = 60
    statistic           = "Average"
    threshold           = 2
    alarm_description   = "ALB has less than 2 healthy targets"
    treat_missing_data  = "breaching"
  }
  
  alb_5xx_errors = {
    alarm_name          = "prod-alb-5xx-errors"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 2
    metric_name         = "HTTPCode_Target_5XX_Count"
    namespace           = "AWS/ApplicationELB"
    period              = 300
    statistic           = "Sum"
    threshold           = 10
    alarm_description   = "ALB is receiving too many 5xx errors"
  }
  
  alb_response_time = {
    alarm_name          = "prod-alb-high-latency"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 2
    metric_name         = "TargetResponseTime"
    namespace           = "AWS/ApplicationELB"
    period              = 300
    statistic           = "Average"
    threshold           = 1
    alarm_description   = "ALB response time exceeds 1 second"
  }
  
  # RDS Monitoring
  rds_cpu_high = {
    alarm_name          = "prod-rds-high-cpu"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 2
    metric_name         = "CPUUtilization"
    namespace           = "AWS/RDS"
    period              = 300
    statistic           = "Average"
    threshold           = 80
    alarm_description   = "RDS CPU utilization is high"
  }
  
  rds_connections_high = {
    alarm_name          = "prod-rds-connection-limit"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 1
    metric_name         = "DatabaseConnections"
    namespace           = "AWS/RDS"
    period              = 60
    statistic           = "Average"
    threshold           = 80
    alarm_description   = "RDS approaching connection limit"
  }
  
  rds_storage_low = {
    alarm_name          = "prod-rds-low-storage"
    comparison_operator = "LessThanThreshold"
    evaluation_periods  = 1
    metric_name         = "FreeStorageSpace"
    namespace           = "AWS/RDS"
    period              = 300
    statistic           = "Average"
    threshold           = 10737418240  # 10 GB in bytes
    alarm_description   = "RDS free storage below 10GB"
  }
  
  # Lambda Monitoring
  lambda_errors = {
    alarm_name          = "prod-lambda-errors"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 2
    metric_name         = "Errors"
    namespace           = "AWS/Lambda"
    period              = 300
    statistic           = "Sum"
    threshold           = 5
    alarm_description   = "Lambda function error rate is high"
  }
  
  lambda_throttles = {
    alarm_name          = "prod-lambda-throttles"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 1
    metric_name         = "Throttles"
    namespace           = "AWS/Lambda"
    period              = 300
    statistic           = "Sum"
    threshold           = 10
    alarm_description   = "Lambda function is being throttled"
  }
}

# Composite alarms for critical scenarios
composite_alarms = {
  application_critical = {
    alarm_name        = "prod-application-critical"
    alarm_description = "Application is experiencing critical issues"
    alarm_rule        = "ALARM(prod-ecs-high-cpu) AND ALARM(prod-ecs-high-memory)"
  }
  
  database_critical = {
    alarm_name        = "prod-database-critical"
    alarm_description = "Database is experiencing critical issues"
    alarm_rule        = "ALARM(prod-rds-high-cpu) OR ALARM(prod-rds-low-storage)"
  }
}

# Anomaly detectors for production
anomaly_detectors = {
  request_anomaly = {
    alarm_name                  = "prod-request-count-anomaly"
    metric_name                 = "RequestCount"
    namespace                   = "AWS/ApplicationELB"
    period                      = 300
    stat                        = "Sum"
    evaluation_periods          = 2
    anomaly_detection_threshold = 2
    alarm_description           = "Unusual request pattern detected"
  }
}

################################################################################
# Log Metric Filters - Production
################################################################################

log_metric_filters = {
  error_count = {
    pattern          = "[time, request_id, level = ERROR*, ...]"
    log_group_name   = "/aws/application/mycompany-prod"
    metric_name      = "ApplicationErrors"
    metric_namespace = "MyApp/Prod"
    metric_value     = "1"
    default_value    = 0
  }
  
  warning_count = {
    pattern          = "[time, request_id, level = WARN*, ...]"
    log_group_name   = "/aws/application/mycompany-prod"
    metric_name      = "ApplicationWarnings"
    metric_namespace = "MyApp/Prod"
    metric_value     = "1"
    default_value    = 0
  }
  
  fatal_errors = {
    pattern          = "[time, request_id, level = FATAL*, ...]"
    log_group_name   = "/aws/application/mycompany-prod"
    metric_name      = "FatalErrors"
    metric_namespace = "MyApp/Prod"
    metric_value     = "1"
    default_value    = 0
  }
}

################################################################################
# CloudWatch Dashboards - Production
################################################################################

dashboards = {
  # Production overview dashboard
  overview = {
    dashboard_name = "prod-overview"
    dashboard_body = jsonencode({
      widgets = [
        {
          type   = "metric"
          x      = 0
          y      = 0
          width  = 12
          height = 6
          properties = {
            metrics = [
              ["AWS/ECS", "CPUUtilization", { stat = "Average" }],
              [".", "MemoryUtilization", { stat = "Average" }]
            ]
            period = 300
            stat   = "Average"
            region = "us-east-1"
            title  = "ECS Resource Utilization"
            yAxis = {
              left = {
                min = 0
                max = 100
              }
            }
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 0
          width  = 12
          height = 6
          properties = {
            metrics = [
              ["AWS/ApplicationELB", "RequestCount", { stat = "Sum" }],
              [".", "HTTPCode_Target_5XX_Count", { stat = "Sum" }]
            ]
            period = 300
            stat   = "Sum"
            region = "us-east-1"
            title  = "ALB Metrics"
          }
        },
        {
          type   = "metric"
          x      = 0
          y      = 6
          width  = 12
          height = 6
          properties = {
            metrics = [
              ["AWS/RDS", "CPUUtilization", { stat = "Average" }],
              [".", "DatabaseConnections", { stat = "Average" }]
            ]
            period = 300
            stat   = "Average"
            region = "us-east-1"
            title  = "RDS Metrics"
          }
        }
      ]
    })
  }
}

################################################################################
# CloudWatch Insights Queries - Production
################################################################################

query_definitions = {
  error_analysis = {
    log_group_names = ["/aws/application/mycompany-prod"]
    query_string    = <<-EOT
      fields @timestamp, @message, @requestId
      | filter @message like /ERROR/
      | sort @timestamp desc
      | limit 100
    EOT
  }
  
  slow_requests = {
    log_group_names = ["/aws/application/mycompany-prod"]
    query_string    = <<-EOT
      fields @timestamp, @duration, @requestId
      | filter @duration > 1000
      | sort @duration desc
      | limit 50
    EOT
  }
  
  top_endpoints = {
    log_group_names = ["/aws/application/mycompany-prod"]
    query_string    = <<-EOT
      fields @timestamp, endpoint
      | stats count() by endpoint
      | sort count() desc
      | limit 20
    EOT
  }
  
  error_rate_by_hour = {
    log_group_names = ["/aws/application/mycompany-prod"]
    query_string    = <<-EOT
      fields @timestamp, @message
      | filter @message like /ERROR/
      | stats count() as error_count by bin(1h)
    EOT
  }
}
