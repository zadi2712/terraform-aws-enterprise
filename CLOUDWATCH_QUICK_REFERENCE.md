# CloudWatch Quick Reference

## 🚀 Quick Start

### Deploy Monitoring

```bash
cd layers/monitoring/environments/dev
terraform init -backend-config=backend.conf
terraform apply
```

### Update Alert Email

```bash
# Edit terraform.tfvars
alert_email = "your-email@example.com"

# Apply
terraform apply
```

---

## 📋 Common Commands

### AWS CLI - Logs

```bash
# List log groups
aws logs describe-log-groups

# Tail logs (live)
aws logs tail /aws/application/myapp --follow

# View logs
aws logs filter-log-events \
  --log-group-name /aws/application/prod \
  --start-time $(date -d '1 hour ago' +%s)000

# Create log group
aws logs create-log-group \
  --log-group-name /aws/application/newapp

# Set retention
aws logs put-retention-policy \
  --log-group-name /aws/application/prod \
  --retention-in-days 90

# Delete log group
aws logs delete-log-group \
  --log-group-name /aws/old/logs
```

### AWS CLI - Alarms

```bash
# List alarms
aws cloudwatch describe-alarms

# Describe specific alarm
aws cloudwatch describe-alarms \
  --alarm-names prod-ecs-high-cpu

# Set alarm state (testing)
aws cloudwatch set-alarm-state \
  --alarm-name prod-ecs-high-cpu \
  --state-value ALARM \
  --state-reason "Testing notification"

# Disable alarm
aws cloudwatch disable-alarm-actions \
  --alarm-names prod-ecs-high-cpu

# Enable alarm
aws cloudwatch enable-alarm-actions \
  --alarm-names prod-ecs-high-cpu

# Delete alarm
aws cloudwatch delete-alarms \
  --alarm-names old-alarm
```

### AWS CLI - Metrics

```bash
# List metrics
aws cloudwatch list-metrics \
  --namespace AWS/ECS

# Get metric statistics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=myapp-prod-ecs \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Put custom metric
aws cloudwatch put-metric-data \
  --namespace MyApp \
  --metric-name RequestCount \
  --value 100 \
  --timestamp $(date -u +%Y-%m-%dT%H:%M:%S)
```

### CloudWatch Insights

```bash
# Start query
QUERY_ID=$(aws logs start-query \
  --log-group-name /aws/application/prod \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20' \
  --query 'queryId' --output text)

# Get results
aws logs get-query-results --query-id $QUERY_ID
```

### Terraform Commands

```bash
# Get outputs
terraform output sns_alerts_topic_arn
terraform output log_group_names
terraform output monitoring_summary

# Update alarms
terraform apply -target=module.cloudwatch

# Destroy specific alarm
terraform destroy -target='module.cloudwatch.aws_cloudwatch_metric_alarm.this["old_alarm"]'
```

---

## 🎯 Configuration Templates

### Development

```hcl
# Minimal monitoring
default_log_retention_days = 7
enable_log_encryption      = false
create_standard_alarms     = false
enable_critical_alerts     = false
```

### Production

```hcl
# Comprehensive monitoring
default_log_retention_days = 90
enable_log_encryption      = true
create_standard_alarms     = true
enable_critical_alerts     = true

alert_email          = "team@example.com"
critical_alert_email = "oncall@example.com"
```

---

## 📊 Alarm Examples

### High CPU

```hcl
metric_alarms = {
  high_cpu = {
    alarm_name          = "high-cpu"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = 2
    metric_name         = "CPUUtilization"
    namespace           = "AWS/EC2"
    period              = 300
    statistic           = "Average"
    threshold           = 80
  }
}
```

### Error Rate

```hcl
log_metric_filters = {
  errors = {
    pattern          = "[time, level = ERROR*, ...]"
    log_group_name   = "/aws/application/prod"
    metric_name      = "Errors"
    metric_namespace = "MyApp"
    metric_value     = "1"
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
  }
}
```

### Composite Alarm

```hcl
composite_alarms = {
  system_down = {
    alarm_name  = "system-completely-down"
    alarm_rule  = "ALARM(high-cpu) AND ALARM(high-memory) AND ALARM(no-healthy-hosts)"
  }
}
```

---

## 🔍 CloudWatch Insights Queries

### Error Analysis

```sql
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 20
```

### Slow Requests

```sql
fields @timestamp, @duration, @requestId
| filter @duration > 1000
| sort @duration desc
| limit 50
```

### Request Stats

```sql
fields @timestamp
| stats count() as requests,
        avg(@duration) as avg_duration,
        max(@duration) as max_duration
  by bin(5m)
```

### Error Rate by Endpoint

```sql
fields endpoint, @message
| filter @message like /ERROR/
| stats count() as errors by endpoint
| sort errors desc
```

---

## 🎨 Dashboard Widgets

### Metric Widget

```json
{
  "type": "metric",
  "properties": {
    "metrics": [
      ["AWS/ECS", "CPUUtilization", { "stat": "Average" }]
    ],
    "period": 300,
    "stat": "Average",
    "region": "us-east-1",
    "title": "ECS CPU"
  }
}
```

### Log Widget

```json
{
  "type": "log",
  "properties": {
    "query": "SOURCE '/aws/application/prod'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc",
    "region": "us-east-1",
    "title": "Recent Errors"
  }
}
```

---

## 🔔 SNS Integration

### Email Subscription

```bash
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789012:myapp-prod-alerts \
  --protocol email \
  --notification-endpoint team@example.com
```

### SMS Subscription

```bash
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789012:myapp-prod-critical \
  --protocol sms \
  --notification-endpoint +1234567890
```

### HTTPS/Webhook

```bash
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789012:myapp-prod-alerts \
  --protocol https \
  --notification-endpoint https://example.com/webhook
```

---

## 📈 Metric Namespaces

### AWS Services

```
AWS/ECS          - ECS metrics
AWS/RDS          - RDS database metrics
AWS/Lambda       - Lambda function metrics
AWS/ApplicationELB - ALB metrics
AWS/EC2          - EC2 instance metrics
AWS/DynamoDB     - DynamoDB table metrics
AWS/S3           - S3 bucket metrics
```

### Custom Metrics

```bash
# Put custom metric
aws cloudwatch put-metric-data \
  --namespace MyApp/Production \
  --metric-name BusinessMetric \
  --value 42 \
  --unit Count \
  --dimensions Environment=prod,Service=api
```

---

## 🛠️ Troubleshooting

### Check Alarm Status

```bash
aws cloudwatch describe-alarms \
  --state-value ALARM \
  --query 'MetricAlarms[*].[AlarmName,StateReason]' \
  --output table
```

### View Recent Logs

```bash
aws logs tail /aws/application/prod \
  --since 1h \
  --format short
```

### Test Log Pattern

```bash
aws logs test-metric-filter \
  --filter-pattern '[time, request_id, level = ERROR*, ...]' \
  --log-event-messages '2024-01-01 12:00:00 req-123 ERROR Database connection failed'
```

### Check SNS Topic

```bash
# Get topic attributes
aws sns get-topic-attributes \
  --topic-arn $(terraform output -raw sns_alerts_topic_arn)

# List subscriptions
aws sns list-subscriptions-by-topic \
  --topic-arn $(terraform output -raw sns_alerts_topic_arn)
```

---

## 💡 Pro Tips

### 1. Use Terraform Outputs

```bash
# Get all monitoring endpoints
terraform output monitoring_endpoints | jq '.'

# Get specific log group
terraform output log_group_names | jq -r '.application'
```

### 2. Anomaly Detection Thresholds

```hcl
# Conservative (fewer false alarms)
anomaly_detection_threshold = 3  # 3 std deviations

# Sensitive (catch more anomalies)
anomaly_detection_threshold = 2  # 2 std deviations
```

### 3. Alarm Actions

```hcl
# Multiple actions
alarm_actions = [
  module.sns_alerts.topic_arn,
  module.sns_pagerduty.topic_arn
]

# Different actions for OK
ok_actions = [
  module.sns_recovery.topic_arn
]
```

### 4. Log Patterns

```
# Common patterns
[time, request_id, level, ...]           # Structured logs
"ERROR"                                   # Simple text match
{ $.level = "ERROR" }                    # JSON logs
```

---

## 📚 Additional Resources

- [CloudWatch Module README](modules/cloudwatch/README.md)
- [Deployment Guide](CLOUDWATCH_DEPLOYMENT_GUIDE.md)
- [Monitoring Layer README](layers/monitoring/README.md)

---

## 🆘 Emergency Procedures

### Disable All Alarms

```bash
# Get all alarm names
ALARMS=$(aws cloudwatch describe-alarms --query 'MetricAlarms[*].AlarmName' --output text)

# Disable
aws cloudwatch disable-alarm-actions --alarm-names $ALARMS
```

### Clear Old Logs

```bash
# Find old log groups
aws logs describe-log-groups \
  --query 'logGroups[?creationTime<`'$(date -d '90 days ago' +%s000)'`].logGroupName' \
  --output text

# Delete (careful!)
aws logs delete-log-group --log-group-name /old/logs
```

### Export Logs

```bash
# Create export task
aws logs create-export-task \
  --log-group-name /aws/application/prod \
  --from $(date -d '7 days ago' +%s)000 \
  --to $(date +%s)000 \
  --destination s3-bucket-name \
  --destination-prefix cloudwatch-exports/
```

---

**Quick Reference v2.0**

