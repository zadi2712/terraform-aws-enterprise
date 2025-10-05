################################################################################
# SNS Module - Main Configuration
# Description: SNS topics and subscriptions
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Module    = "sns"
      ManagedBy = "terraform"
    }
  )
}

# Add your resource configurations here
# Resources: aws_sns_topic, aws_sns_topic_subscription
