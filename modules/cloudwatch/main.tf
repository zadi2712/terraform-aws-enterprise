################################################################################
# CLOUDWATCH Module - Main Configuration
# Description: CloudWatch dashboards and alarms
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Module    = "cloudwatch"
      ManagedBy = "terraform"
    }
  )
}

# Add your resource configurations here
# Resources: aws_cloudwatch_dashboard, aws_cloudwatch_metric_alarm
