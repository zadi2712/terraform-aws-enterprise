# CloudWatch Module

## Description

Enterprise-grade AWS CloudWatch module for comprehensive monitoring, logging, and alerting with support for log groups, metric alarms, dashboards, and anomaly detection.

## Features

- **Log Groups**: Centralized logging with retention and KMS encryption
- **Metric Alarms**: Standard and anomaly detection alarms
- **Composite Alarms**: Complex alarm conditions
- **Dashboards**: Custom CloudWatch dashboards
- **Log Metric Filters**: Extract metrics from logs
- **Query Definitions**: Saved CloudWatch Insights queries
- **Anomaly Detection**: ML-powered anomaly detection
- **Data Protection**: PII/sensitive data masking

## Resources Created

- `aws_cloudwatch_log_group` - Log groups with encryption
- `aws_cloudwatch_log_stream` - Log streams
- `aws_cloudwatch_log_metric_filter` - Metrics from logs
- `aws_cloudwatch_metric_alarm` - Metric alarms
- `aws_cloudwatch_composite_alarm` - Composite alarms
- `aws_cloudwatch_dashboard` - Monitoring dashboards
- `aws_cloudwatch_query_definition` - Saved queries
- `aws_cloudwatch_log_resource_policy` - Service integration
- `aws_cloudwatch_log_data_protection_policy` - Data masking

## Usage

### Basic Log Groups

```hcl
module "cloudwatch_basic" {
  source = "../../modules/cloudwatch"

  log_groups = {
    application = {
      name              = "/aws/application/myapp"
      retention_in_days = 30
    }
    
    lambda = {
      name              = "/aws/lambda/myfunction"
      retention_in_days = 7
    }
  }

  tags = {
    Environment = "production"
  }
}
```

### Production Monitoring Stack

```hcl
module "cloudwatch_prod" {
  source = "../../modules/cloudwatch"

  default_log_retention_days = 90
  default_kms_key_id         = module.kms.key_arn

  # Log Groups
  log_groups = {
    application = {
      name              = "/aws/application/prod"
      retention_in_days = 90
      kms_key_id        = module.kms.key_arn
    }
    
    ecs = {
      name              = "/aws/ecs/prod"
      retention_in_days = 30
    }
  }

  # Metric Alarms
  metric_alarms = {
    high_cpu = {
      alarm_name          = "prod-high-cpu"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "CPUUtilization"
      namespace           = "AWS/EC2"
      period              = 300
      statistic           = "Average"
      threshold           = 80
      alarm_description   = "CPU utilization is too high"
      alarm_actions       = [module.sns.topic_arn]
      
      dimensions = {
        InstanceId = "i-1234567890abcdef0"
      }
    }
    
    high_error_rate = {
      alarm_name          = "prod-high-error-rate"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "Errors"
      namespace           = "AWS/Lambda"
      period              = 60
      statistic           = "Sum"
      threshold           = 10
      alarm_actions       = [module.sns.topic_arn]
    }
  }

  # Log Metric Filters
  log_metric_filters = {
    error_count = {
      pattern          = "[time, request_id, event_type = ERROR*, ...]"
      log_group_name   = "/aws/application/prod"
      metric_name      = "ApplicationErrors"
      metric_namespace = "CustomMetrics"
      metric_value     = "1"
      default_value    = 0
    }
  }

  # Dashboard
  dashboards = {
    main = {
      dashboard_name = "production-overview"
      dashboard_body = jsonencode({
        widgets = [
          {
            type = "metric"
            properties = {
              metrics = [
                ["AWS/EC2", "CPUUtilization", { stat = "Average" }]
              ]
              period = 300
              stat   = "Average"
              region = "us-east-1"
              title  = "EC2 CPU Utilization"
            }
          }
        ]
      })
    }
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

### Anomaly Detection

```hcl
module "cloudwatch_anomaly" {
  source = "../../modules/cloudwatch"

  anomaly_detectors = {
    request_anomaly = {
      alarm_name                  = "request-count-anomaly"
      metric_name                 = "RequestCount"
      namespace                   = "AWS/ApplicationELB"
      period                      = 300
      stat                        = "Sum"
      evaluation_periods          = 2
      anomaly_detection_threshold = 2
      alarm_description           = "Detect unusual request patterns"
      alarm_actions               = [module.sns.topic_arn]
      
      dimensions = {
        LoadBalancer = "app/my-alb/1234567890"
      }
    }
  }
}
```

### Composite Alarms

```hcl
module "cloudwatch_composite" {
  source = "../../modules/cloudwatch"

  metric_alarms = {
    high_cpu = { ... }
    high_memory = { ... }
    high_disk = { ... }
  }

  composite_alarms = {
    system_unhealthy = {
      alarm_name        = "system-critical"
      alarm_description = "Multiple system metrics are critical"
      alarm_rule        = "ALARM(high_cpu) OR ALARM(high_memory) OR ALARM(high_disk)"
      alarm_actions     = [module.sns.critical_topic_arn]
    }
  }
}
```

### CloudWatch Insights Queries

```hcl
module "cloudwatch_queries" {
  source = "../../modules/cloudwatch"

  query_definitions = {
    error_analysis = {
      log_group_names = ["/aws/application/prod"]
      query_string    = <<-EOT
        fields @timestamp, @message
        | filter @message like /ERROR/
        | sort @timestamp desc
        | limit 20
      EOT
    }
    
    slow_requests = {
      log_group_names = ["/aws/lambda/myfunction"]
      query_string    = <<-EOT
        fields @timestamp, @duration
        | filter @duration > 1000
        | sort @duration desc
        | limit 50
      EOT
    }
  }
}
```

## Common Monitoring Patterns

### Application Monitoring

```hcl
log_groups = {
  app_logs = {
    name              = "/aws/application/myapp"
    retention_in_days = 30
  }
}

log_metric_filters = {
  errors = {
    pattern          = "[time, request_id, level = ERROR*, ...]"
    log_group_name   = "/aws/application/myapp"
    metric_name      = "Errors"
    metric_namespace = "MyApp"
    metric_value     = "1"
  }
  
  latency = {
    pattern          = "[time, request_id, ..., latency]"
    log_group_name   = "/aws/application/myapp"
    metric_name      = "ResponseTime"
    metric_namespace = "MyApp"
    metric_value     = "$latency"
  }
}

metric_alarms = {
  error_rate = {
    alarm_name          = "high-error-rate"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 2
    metric_name         = "Errors"
    namespace           = "MyApp"
    period              = 300
    statistic           = "Sum"
    threshold           = 10
    alarm_actions       = [var.sns_topic_arn]
  }
}
```

### Infrastructure Monitoring

```hcl
metric_alarms = {
  ec2_cpu = {
    alarm_name          = "ec2-high-cpu"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 2
    metric_name         = "CPUUtilization"
    namespace           = "AWS/EC2"
    period              = 300
    statistic           = "Average"
    threshold           = 80
    alarm_actions       = [var.sns_topic_arn]
  }
  
  rds_connections = {
    alarm_name          = "rds-connection-limit"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 1
    metric_name         = "DatabaseConnections"
    namespace           = "AWS/RDS"
    period              = 300
    statistic           = "Average"
    threshold           = 80
    alarm_actions       = [var.sns_topic_arn]
  }
}
```

## Best Practices

### 1. Log Retention

```hcl
# Development: 7 days
retention_in_days = 7

# Production: 30-90 days
retention_in_days = 90

# Compliance: 365+ days
retention_in_days = 365
```

### 2. Encryption

```hcl
log_groups = {
  sensitive_data = {
    name       = "/aws/application/sensitive"
    kms_key_id = module.kms.key_arn  # Always encrypt in production
  }
}
```

### 3. Alarm Actions

```hcl
metric_alarms = {
  critical = {
    alarm_actions             = [var.critical_sns_topic]
    ok_actions                = [var.recovery_sns_topic]
    insufficient_data_actions = []  # Don't alert on missing data
  }
}
```

### 4. Treat Missing Data

```hcl
metric_alarms = {
  web_traffic = {
    treat_missing_data = "notBreaching"  # For metrics that may have gaps
  }
  
  health_check = {
    treat_missing_data = "breaching"  # For critical health metrics
  }
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| log_groups | Map of log groups to create | map(object) | `{}` |
| default_log_retention_days | Default log retention | number | `30` |
| default_kms_key_id | Default KMS key for encryption | string | `null` |
| metric_alarms | Map of metric alarms | map(object) | `{}` |
| composite_alarms | Map of composite alarms | map(object) | `{}` |
| dashboards | Map of dashboards | map(object) | `{}` |
| log_metric_filters | Map of metric filters | map(object) | `{}` |
| query_definitions | Map of query definitions | map(object) | `{}` |
| anomaly_detectors | Map of anomaly detectors | map(object) | `{}` |
| tags | Resource tags | map(string) | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| log_group_names | Map of log group names |
| log_group_arns | Map of log group ARNs |
| metric_alarm_names | Map of alarm names |
| metric_alarm_arns | Map of alarm ARNs |
| dashboard_names | Map of dashboard names |
| monitoring_summary | Summary of all resources |

## Alarm Comparison Operators

- `GreaterThanOrEqualToThreshold`
- `GreaterThanThreshold`
- `LessThanThreshold`
- `LessThanOrEqualToThreshold`
- `LessThanLowerOrGreaterThanUpperThreshold` (anomaly detection)

## Statistics

- `Average`
- `Sum`
- `Minimum`
- `Maximum`
- `SampleCount`
- Extended: `p50`, `p90`, `p95`, `p99`

## Treat Missing Data Options

- `missing` - Missing data treated as missing (default)
- `notBreaching` - Missing data treated as good
- `breaching` - Missing data treated as bad
- `ignore` - Current alarm state maintained

## References

- [CloudWatch Documentation](https://docs.aws.amazon.com/cloudwatch/)
- [CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/)
- [CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [Anomaly Detection](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Anomaly_Detection.html)
