# Monitoring Layer

## Overview

The monitoring layer provides comprehensive observability for the entire enterprise infrastructure through CloudWatch logs, metrics, alarms, dashboards, and SNS notifications.

**Version:** 2.0  
**Status:** Production Ready

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Monitoring Layer                            │
│                                                           │
│  ┌──────────────┐       ┌──────────────────────────┐   │
│  │ SNS Topics   │       │  CloudWatch Module        │   │
│  │ • Alerts     │◄──────┤  • Log Groups (5+)       │   │
│  │ • Critical   │       │  • Metric Alarms (20+)   │   │
│  └──────┬───────┘       │  • Dashboards            │   │
│         │               │  • Anomaly Detection     │   │
│         │               │  • Log Metric Filters    │   │
│         ▼               │  • Insights Queries      │   │
│  ┌──────────────┐       └──────────────────────────┘   │
│  │ Notifications│                                        │
│  │ • Email      │                                        │
│  │ • Slack      │                                        │
│  │ • PagerDuty  │                                        │
│  └──────────────┘                                        │
└─────────────────────────────────────────────────────────┘
```

---

## Features

### Logging
- ✅ **Log Groups** - Organized, encrypted logging
- ✅ **Log Streams** - Categorized log streams
- ✅ **Log Retention** - Configurable retention policies
- ✅ **KMS Encryption** - Encrypted logs for compliance

### Alerting
- ✅ **Metric Alarms** - Standard threshold-based alerts
- ✅ **Composite Alarms** - Multi-metric conditions
- ✅ **Anomaly Detection** - ML-powered alerting
- ✅ **SNS Integration** - Email, SMS, webhook notifications

### Analytics
- ✅ **Log Metric Filters** - Extract metrics from logs
- ✅ **CloudWatch Insights** - SQL-like log analysis
- ✅ **Saved Queries** - Reusable query templates

### Visualization
- ✅ **Dashboards** - Custom monitoring views
- ✅ **Widgets** - Metric, log, and alarm widgets

---

## Quick Start

### 1. Configure Alerts

```bash
cd layers/monitoring/environments/dev
vi terraform.tfvars
```

Update:
```hcl
alert_email = "your-team@example.com"
```

### 2. Deploy

```bash
terraform init -backend-config=backend.conf
terraform apply
```

### 3. Confirm Email

Check your inbox and confirm SNS subscription.

### 4. Verify

```bash
terraform output sns_alerts_topic_arn
terraform output log_group_names
terraform output monitoring_summary
```

---

## Configuration Examples

### Development - Minimal Monitoring

```hcl
# Cost-optimized for development
default_log_retention_days = 7
enable_log_encryption      = false
create_standard_alarms     = false
enable_critical_alerts     = false

alert_email = "devteam@example.com"
```

### Production - Full Observability

```hcl
# Comprehensive production monitoring
default_log_retention_days = 90
lambda_log_retention_days  = 30
ecs_log_retention_days     = 60

enable_log_encryption  = true
create_standard_alarms = true
enable_critical_alerts = true

alert_email          = "platform-team@example.com"
critical_alert_email = "oncall@example.com"

# Production alarms
metric_alarms = {
  ecs_cpu_high    = { ... }
  alb_5xx_errors  = { ... }
  rds_cpu_high    = { ... }
  # ... 20+ alarms
}

# Composite alarms
composite_alarms = {
  application_critical = { ... }
  database_critical    = { ... }
}

# Anomaly detection
anomaly_detectors = {
  traffic_anomaly = { ... }
}

# Dashboards
dashboards = {
  overview = { ... }
}
```

---

## Monitoring Patterns

### Application Logging

```hcl
application_log_groups = {
  api = {
    name              = "/aws/application/api-prod"
    retention_in_days = 90
    kms_key_id        = data.terraform_remote_state.security.outputs.kms_key_arn
  }
}

log_metric_filters = {
  api_errors = {
    pattern          = "[time, request_id, level = ERROR*, ...]"
    log_group_name   = "/aws/application/api-prod"
    metric_name      = "APIErrors"
    metric_namespace = "MyApp"
    metric_value     = "1"
  }
}

metric_alarms = {
  api_error_rate = {
    alarm_name          = "api-high-error-rate"
    metric_name         = "APIErrors"
    namespace           = "MyApp"
    threshold           = 10
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 2
    period              = 300
    statistic           = "Sum"
  }
}
```

### Infrastructure Monitoring

```hcl
metric_alarms = {
  # ECS
  ecs_cpu = {
    metric_name = "CPUUtilization"
    namespace   = "AWS/ECS"
    dimensions  = {
      ClusterName = "myapp-prod-ecs"
    }
  }
  
  # RDS
  rds_connections = {
    metric_name = "DatabaseConnections"
    namespace   = "AWS/RDS"
    dimensions  = {
      DBInstanceIdentifier = "myapp-prod-db"
    }
  }
  
  # ALB
  alb_latency = {
    metric_name = "TargetResponseTime"
    namespace   = "AWS/ApplicationELB"
    dimensions  = {
      LoadBalancer = "app/myapp-prod/abc123"
    }
  }
}
```

---

## Outputs

### SNS Topics

```bash
terraform output sns_alerts_topic_arn     # General alerts
terraform output sns_critical_topic_arn   # Critical alerts
```

### CloudWatch Resources

```bash
terraform output log_group_names          # All log groups
terraform output metric_alarm_names       # All alarms
terraform output dashboard_names          # All dashboards
terraform output monitoring_summary       # Resource counts
```

---

## Post-Deployment Tasks

### 1. Confirm SNS Subscriptions

```bash
# Check inbox for confirmation emails
# Click "Confirm subscription" links
```

### 2. Configure Application Logging

```bash
# Update application config to use log groups
LOG_GROUP="/aws/application/myapp-prod"

# In your application:
# logging.config(group=$LOG_GROUP, stream=$HOSTNAME)
```

### 3. Test Alarms

```bash
# Trigger test alarm
aws cloudwatch set-alarm-state \
  --alarm-name prod-ecs-high-cpu \
  --state-value ALARM \
  --state-reason "Testing notification"

# Verify email received
```

### 4. Create Custom Dashboards

Access AWS Console:
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:
```

---

## Maintenance

### Weekly Tasks

- Review triggered alarms
- Check dashboard metrics
- Analyze error logs
- Verify log retention

### Monthly Tasks

- Optimize alarm thresholds
- Clean up old log groups
- Review CloudWatch costs
- Update query definitions

### Quarterly Tasks

- Review monitoring coverage
- Update alerting strategy
- Audit SNS subscriptions
- Optimize dashboards

---

## Troubleshooting

### No Logs Appearing

```bash
# Check log group exists
aws logs describe-log-groups --log-group-name-prefix /aws/application/

# Check IAM permissions
# Application needs: logs:CreateLogStream, logs:PutLogEvents

# Test manually
aws logs put-log-events \
  --log-group-name /aws/application/test \
  --log-stream-name test \
  --log-events timestamp=$(date +%s000),message="Test"
```

### Alarm Not Triggering

```bash
# Check alarm configuration
aws cloudwatch describe-alarms --alarm-names my-alarm

# View metric data
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Dashboard Not Loading

```bash
# Verify dashboard exists
aws cloudwatch list-dashboards

# Get dashboard definition
aws cloudwatch get-dashboard --dashboard-name prod-overview
```

---

## Related Documentation

- [CloudWatch Module README](../../modules/cloudwatch/README.md)
- [CloudWatch Deployment Guide](../../CLOUDWATCH_DEPLOYMENT_GUIDE.md)
- [CloudWatch Quick Reference](../../CLOUDWATCH_QUICK_REFERENCE.md)
- [Architecture Documentation](../../docs/ARCHITECTURE.md)

---

## Cost Optimization Tips

1. **Reduce log retention** in non-production environments
2. **Filter logs** before ingestion (use metric filters wisely)
3. **Delete unused** log groups and alarms
4. **Consolidate dashboards** to stay under free tier
5. **Use anomaly detection** sparingly (costs per metric)
6. **Archive old logs** to S3 for long-term storage

---

## Best Practices

1. ✅ **Encrypt logs** in production
2. ✅ **Use meaningful alarm names** (include environment)
3. ✅ **Set appropriate thresholds** (avoid alarm fatigue)
4. ✅ **Use composite alarms** for complex conditions
5. ✅ **Tag all resources** for cost allocation
6. ✅ **Save common queries** for reuse
7. ✅ **Test alarms** after deployment
8. ✅ **Monitor CloudWatch costs** regularly

---

**Monitoring Layer v2.0** - Enterprise-grade observability

