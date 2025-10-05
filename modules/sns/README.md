# SNS Topic Module

Amazon Simple Notification Service for alerts and notifications.

## Features
- SNS Topics
- Email subscriptions
- SMS subscriptions
- SQS subscriptions
- Lambda subscriptions
- Encryption support

## Usage

```hcl
module "alerts" {
  source = "../../../modules/sns"

  name         = "critical-alerts"
  display_name = "Critical Alerts"
  
  subscriptions = [
    {
      protocol = "email"
      endpoint = "ops-team@company.com"
    },
    {
      protocol = "sms"
      endpoint = "+1-555-0100"
    }
  ]
  
  kms_master_key_id = module.kms.key_id
  
  tags = {
    Environment = "production"
    AlertLevel  = "critical"
  }
}
```
