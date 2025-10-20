# CloudWatch Deployment Guide

## Overview

Complete guide for deploying and managing AWS CloudWatch monitoring infrastructure using the enterprise Terraform modules.

**Version:** 2.0  
**Last Updated:** October 20, 2025  
**Status:** ✅ Production Ready

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Deployment Steps](#deployment-steps)
4. [Configuration Guide](#configuration-guide)
5. [Monitoring Patterns](#monitoring-patterns)
6. [Dashboards](#dashboards)
7. [Alerting Strategy](#alerting-strategy)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### Monitoring Stack

```
┌────────────────────────────────────────────────────┐
│              Monitoring Layer                       │
│                                                      │
│  ┌──────────────┐        ┌──────────────────┐     │
│  │  SNS Topics  │        │   CloudWatch     │     │
│  │              │        │                  │     │
│  │ • Alerts     │◄───────┤ • Log Groups     │     │
│  │ • Critical   │        │ • Metric Alarms  │     │
│  └──────────────┘        │ • Dashboards     │     │
│         │                │ • Anomaly        │     │
│         ▼                │   Detection      │     │
│  ┌──────────────┐        └──────────────────┘     │
│  │  Email/SMS   │                                  │
│  │  PagerDuty   │                                  │
│  └──────────────┘                                  │
└────────────────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────────────────┐
│         Application & Infrastructure                │
│  • ECS/EKS  • Lambda  • RDS  • ALB  • EC2         │
└────────────────────────────────────────────────────┘
```

### Module Structure

```
modules/cloudwatch/
├── main.tf          # Log groups, alarms, dashboards
├── variables.tf     # Configuration options
├── outputs.tf       # Monitoring resource outputs
└── README.md        # Module documentation

layers/monitoring/
├── main.tf          # SNS + CloudWatch integration
├── variables.tf     # Layer configuration
├── outputs.tf       # Exposed monitoring endpoints
└── environments/
    ├── dev/
    ├── qa/
    ├── uat/
    └── prod/
```

---

## Prerequisites

### Required Layers

Deploy these layers first:

1. **Security Layer** (for KMS encryption)
   ```bash
   cd layers/security/environments/dev
   terraform apply
   ```

2. **Networking Layer** (if monitoring VPC resources)
3. **Compute Layer** (if monitoring ECS/EKS)

### Tools Required

- Terraform >= 1.5.0
- AWS CLI v2
- jq (for JSON processing)

---

## Deployment Steps

### Step 1: Configure Alert Emails

Edit environment tfvars:

```bash
cd layers/monitoring/environments/dev
vi terraform.tfvars
```

Update email addresses:

```hcl
# General alerts
alert_email = "devteam@example.com"

# Critical alerts (production only)
critical_alert_email = "oncall@example.com"
```

### Step 2: Configure Log Retention

```hcl
# Development: Short retention to save costs
default_log_retention_days = 7
lambda_log_retention_days  = 3

# Production: Compliance-driven retention
default_log_retention_days = 90
lambda_log_retention_days  = 30
```

### Step 3: Enable Encryption (Production)

```hcl
# Encrypt logs with KMS
enable_log_encryption = true
```

### Step 4: Initialize and Deploy

```bash
cd layers/monitoring/environments/dev
terraform init -backend-config=backend.conf
terraform validate
terraform plan
terraform apply
```

### Step 5: Confirm SNS Subscriptions

Check your email and confirm SNS subscriptions:

```
Subject: AWS Notification - Subscription Confirmation
Click the "Confirm subscription" link
```

### Step 6: Verify Deployment

```bash
# Check SNS topics
terraform output sns_alerts_topic_arn

# Check log groups
terraform output log_group_names

# Check alarms
terraform output metric_alarm_names

# View monitoring summary
terraform output monitoring_summary
```

---

## Configuration Guide

### Log Groups

#### Standard Log Groups

```hcl
# Automatically created when enabled
create_standard_log_groups = true

# Creates:
# - /aws/application/{project}-{env}
# - /aws/lambda/{project}-{env}
# - /aws/ecs/{project}-{env}
```

#### Custom Application Log Groups

```hcl
application_log_groups = {
  api = {
    name              = "/aws/application/api-prod"
    retention_in_days = 90
    kms_key_id        = module.kms.key_arn
  }
  
  worker = {
    name              = "/aws/application/worker-prod"
    retention_in_days = 60
  }
  
  scheduler = {
    name              = "/aws/application/scheduler-prod"
    retention_in_days = 30
  }
}
```

### Metric Alarms

#### Basic Alarm

```hcl
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
    alarm_description   = "CPU utilization is high"
    treat_missing_data  = "notBreaching"
  }
}
```

#### Advanced Alarm with Datapoints

```hcl
metric_alarms = {
  sustained_high_cpu = {
    alarm_name          = "sustained-high-cpu"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 5
    datapoints_to_alarm = 3  # 3 out of 5 periods
    metric_name         = "CPUUtilization"
    namespace           = "AWS/EC2"
    period              = 300
    statistic           = "Average"
    threshold           = 70
  }
}
```

### Composite Alarms

```hcl
composite_alarms = {
  application_down = {
    alarm_name        = "application-completely-down"
    alarm_description = "All health checks failing"
    alarm_rule        = "ALARM(alb-unhealthy) AND ALARM(ecs-no-tasks)"
  }
}
```

### Anomaly Detection

```hcl
anomaly_detectors = {
  traffic_anomaly = {
    alarm_name                  = "unusual-traffic-pattern"
    metric_name                 = "RequestCount"
    namespace                   = "AWS/ApplicationELB"
    period                      = 300
    stat                        = "Sum"
    evaluation_periods          = 2
    anomaly_detection_threshold = 2  # 2 standard deviations
    alarm_description           = "Traffic pattern is unusual"
  }
}
```

### Log Metric Filters

```hcl
log_metric_filters = {
  error_rate = {
    pattern          = "[time, request_id, level = ERROR*, ...]"
    log_group_name   = "/aws/application/prod"
    metric_name      = "Errors"
    metric_namespace = "MyApp"
    metric_value     = "1"
    default_value    = 0
  }
  
  response_time = {
    pattern          = "[time, request_id, ..., duration]"
    log_group_name   = "/aws/application/prod"
    metric_name      = "ResponseTime"
    metric_namespace = "MyApp"
    metric_value     = "$duration"
    unit             = "Milliseconds"
  }
}
```

---

## Monitoring Patterns

### Application Monitoring

```hcl
# 1. Create log groups
application_log_groups = {
  app = {
    name              = "/aws/application/myapp"
    retention_in_days = 30
  }
}

# 2. Extract metrics from logs
log_metric_filters = {
  errors = {
    pattern          = "[time, level = ERROR*, ...]"
    log_group_name   = "/aws/application/myapp"
    metric_name      = "Errors"
    metric_namespace = "MyApp"
    metric_value     = "1"
  }
}

# 3. Create alarms
metric_alarms = {
  high_error_rate = {
    alarm_name          = "myapp-high-errors"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 2
    metric_name         = "Errors"
    namespace           = "MyApp"
    period              = 300
    statistic           = "Sum"
    threshold           = 10
  }
}
```

### Infrastructure Monitoring

#### ECS Monitoring

```hcl
metric_alarms = {
  ecs_cpu = {
    alarm_name          = "ecs-high-cpu"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 2
    metric_name         = "CPUUtilization"
    namespace           = "AWS/ECS"
    period              = 300
    statistic           = "Average"
    threshold           = 80
    
    dimensions = {
      ClusterName = "myapp-prod-ecs"
      ServiceName = "myapp"
    }
  }
}
```

#### RDS Monitoring

```hcl
metric_alarms = {
  rds_cpu = {
    alarm_name          = "rds-high-cpu"
    metric_name         = "CPUUtilization"
    namespace           = "AWS/RDS"
    threshold           = 80
    # ...
  }
  
  rds_storage = {
    alarm_name          = "rds-low-storage"
    metric_name         = "FreeStorageSpace"
    namespace           = "AWS/RDS"
    comparison_operator = "LessThanThreshold"
    threshold           = 10737418240  # 10 GB
    # ...
  }
}
```

#### ALB Monitoring

```hcl
metric_alarms = {
  alb_5xx = {
    alarm_name          = "alb-5xx-errors"
    metric_name         = "HTTPCode_Target_5XX_Count"
    namespace           = "AWS/ApplicationELB"
    threshold           = 10
    # ...
  }
  
  alb_latency = {
    alarm_name          = "alb-high-latency"
    metric_name         = "TargetResponseTime"
    namespace           = "AWS/ApplicationELB"
    threshold           = 1  # 1 second
    # ...
  }
}
```

---

## Dashboards

### Creating a Dashboard

```hcl
dashboards = {
  overview = {
    dashboard_name = "prod-overview"
    dashboard_body = jsonencode({
      widgets = [
        {
          type   = "metric"
          width  = 12
          height = 6
          properties = {
            metrics = [
              ["AWS/ECS", "CPUUtilization"],
              [".", "MemoryUtilization"]
            ]
            period = 300
            stat   = "Average"
            region = "us-east-1"
            title  = "ECS Metrics"
          }
        }
      ]
    })
  }
}
```

### Dashboard from File

```hcl
dashboards = {
  main = {
    dashboard_name = "production-main"
    dashboard_body = file("${path.module}/dashboards/main.json")
  }
}
```

---

## Alerting Strategy

### Alert Levels

#### Level 1: Informational (Dev/QA)
- Non-critical warnings
- Performance degradation
- Resource utilization trends

#### Level 2: Warning (All Environments)
- Resource limits approaching
- Increased error rates
- Performance issues

#### Level 3: Critical (Production)
- Service outages
- Data loss risks
- Security incidents

### SNS Topic Strategy

```hcl
# Development
enable_sns_alerts      = true
enable_critical_alerts = false

# Production
enable_sns_alerts      = true
enable_critical_alerts = true

# Route critical alarms to separate topic
alarm_actions = [module.sns_critical[0].topic_arn]
```

---

## Best Practices

### 1. Log Retention

| Environment | Application | Lambda | ECS |
|-------------|-------------|--------|-----|
| Dev | 7 days | 3 days | 7 days |
| QA | 14 days | 7 days | 14 days |
| UAT | 30 days | 14 days | 30 days |
| Prod | 90 days | 30 days | 60 days |

### 2. Alarm Configuration

```hcl
# Use multiple evaluation periods
evaluation_periods = 3

# Use datapoints_to_alarm to reduce false positives
datapoints_to_alarm = 2  # 2 out of 3 must breach

# Handle missing data appropriately
treat_missing_data = "notBreaching"  # For metrics with gaps
```

### 3. Cost Optimization

```hcl
# Development: Minimal monitoring
create_standard_alarms = false
anomaly_detectors     = {}
default_log_retention_days = 7

# Production: Comprehensive monitoring
create_standard_alarms = true
anomaly_detectors     = { ... }
default_log_retention_days = 90
```

### 4. Encryption

```hcl
# Always encrypt logs in production
enable_log_encryption = true

# Optional in development
enable_log_encryption = false
```

---

## Post-Deployment

### 1. Confirm SNS Subscriptions

```bash
# List subscriptions
aws sns list-subscriptions

# Check pending confirmations
aws sns list-subscriptions-by-topic \
  --topic-arn $(terraform output -raw sns_alerts_topic_arn)
```

### 2. Verify Log Groups

```bash
# List log groups
aws logs describe-log-groups \
  --log-group-name-prefix /aws/application/

# Test logging
aws logs create-log-stream \
  --log-group-name /aws/application/mycompany-dev \
  --log-stream-name test

aws logs put-log-events \
  --log-group-name /aws/application/mycompany-dev \
  --log-stream-name test \
  --log-events timestamp=$(date +%s000),message="Test message"
```

### 3. Test Alarms

```bash
# Set alarm state to test
aws cloudwatch set-alarm-state \
  --alarm-name prod-ecs-high-cpu \
  --state-value ALARM \
  --state-reason "Testing alarm notification"

# Check alarm history
aws cloudwatch describe-alarm-history \
  --alarm-name prod-ecs-high-cpu \
  --max-records 5
```

### 4. View Dashboards

```bash
# Open in AWS Console
echo "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=prod-overview"

# Or use AWS CLI
aws cloudwatch get-dashboard \
  --dashboard-name prod-overview
```

---

## CloudWatch Insights Queries

### Saved Queries

Access your predefined queries in AWS Console:
- CloudWatch > Logs > Insights > Queries

Or via CLI:

```bash
# List query definitions
aws logs describe-query-definitions

# Run a query
aws logs start-query \
  --log-group-name /aws/application/prod \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/'
```

---

## Monitoring Checklist

### Initial Setup

- [ ] Deploy security layer (for KMS)
- [ ] Update alert email addresses
- [ ] Configure log retention periods
- [ ] Enable log encryption (prod)
- [ ] Deploy monitoring layer
- [ ] Confirm SNS subscriptions
- [ ] Test alarm notifications

### Ongoing Operations

- [ ] Review alarms weekly
- [ ] Check dashboard metrics
- [ ] Analyze CloudWatch Insights logs
- [ ] Optimize log retention
- [ ] Update alarm thresholds
- [ ] Review anomaly detections
- [ ] Clean up unused log groups

---

## Troubleshooting

### SNS Subscriptions Not Confirmed

```bash
# Resend confirmation
aws sns subscribe \
  --topic-arn $(terraform output -raw sns_alerts_topic_arn) \
  --protocol email \
  --notification-endpoint your-email@example.com
```

### Alarms Not Triggering

```bash
# Check alarm state
aws cloudwatch describe-alarms \
  --alarm-names prod-ecs-high-cpu

# View alarm history
aws cloudwatch describe-alarm-history \
  --alarm-name prod-ecs-high-cpu

# Test manually
aws cloudwatch set-alarm-state \
  --alarm-name prod-ecs-high-cpu \
  --state-value ALARM \
  --state-reason "Testing"
```

### Log Groups Not Receiving Data

```bash
# Check log group exists
aws logs describe-log-groups \
  --log-group-name-prefix /aws/application/

# Check IAM permissions
# Ensure services have logs:CreateLogStream and logs:PutLogEvents

# Check log streams
aws logs describe-log-streams \
  --log-group-name /aws/application/prod
```

### High CloudWatch Costs

```bash
# Identify expensive log groups
aws logs describe-log-groups \
  --query 'sort_by(logGroups, &storedBytes)[-10:][name, storedBytes]' \
  --output table

# Reduce retention
terraform apply -var="default_log_retention_days=7"

# Delete old log groups
aws logs delete-log-group --log-group-name /aws/old/logs
```

---

## Environment-Specific Patterns

### Development

```hcl
# Minimal monitoring to save costs
default_log_retention_days = 7
enable_log_encryption      = false
create_standard_alarms     = false
enable_critical_alerts     = false

# Focus on debugging
query_definitions = {
  debug_errors = { ... }
}
```

### Production

```hcl
# Comprehensive monitoring
default_log_retention_days = 90
enable_log_encryption      = true
create_standard_alarms     = true
enable_critical_alerts     = true

# Multiple alarm levels
metric_alarms      = { ... }
composite_alarms   = { ... }
anomaly_detectors  = { ... }

# Multiple dashboards
dashboards = {
  overview    = { ... }
  application = { ... }
  database    = { ... }
}
```

---

## Integration Examples

### With ECS

```hcl
# ECS task definition references log group
container_definitions = jsonencode([{
  logConfiguration = {
    logDriver = "awslogs"
    options = {
      "awslogs-group"         = "/aws/ecs/mycompany-prod"
      "awslogs-region"        = "us-east-1"
      "awslogs-stream-prefix" = "myapp"
    }
  }
}])
```

### With Lambda

```hcl
# Lambda automatically logs to /aws/lambda/{function-name}
# But you can customize:

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.example.function_name}"
  retention_in_days = 30
  kms_key_id        = module.kms.key_arn
}
```

### With ALB

```hcl
# ALB access logs go to S3, but metrics to CloudWatch
metric_alarms = {
  alb_errors = {
    namespace   = "AWS/ApplicationELB"
    metric_name = "HTTPCode_Target_5XX_Count"
    dimensions = {
      LoadBalancer = "app/my-alb/1234567890"
    }
  }
}
```

---

## References

- [CloudWatch Logs Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/)
- [CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [CloudWatch Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html)
- [Anomaly Detection](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Anomaly_Detection.html)

---

**End of Deployment Guide**

