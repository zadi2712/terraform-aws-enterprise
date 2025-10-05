# CloudWatch Module

Amazon CloudWatch dashboards, alarms, and log groups.

## Features
- CloudWatch Dashboards
- Metric Alarms
- Log Groups
- Metric Filters
- Composite Alarms

## Usage

```hcl
module "monitoring" {
  source = "../../../modules/cloudwatch"

  dashboard_name = "production-overview"
  
  log_groups = {
    application = {
      name              = "/aws/application/prod"
      retention_in_days = 30
    }
  }
  
  metric_alarms = {
    high_cpu = {
      alarm_name          = "high-cpu-utilization"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "CPUUtilization"
      namespace           = "AWS/EC2"
      period              = 300
      statistic           = "Average"
      threshold           = 80
      alarm_actions       = [module.sns.topic_arn]
    }
  }
  
  tags = {
    Environment = "production"
  }
}
```
