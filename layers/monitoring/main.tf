################################################################################
# Monitoring Layer - CloudWatch, SNS, Alarms
# Version: 2.0
# Description: Comprehensive monitoring with CloudWatch integration
################################################################################

terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = merge(var.common_tags, { Layer = "monitoring" })
  }
}

# Data sources
data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket = "terraform-state-${var.environment}-${data.aws_caller_identity.current.account_id}"
    key    = "layers/security/${var.environment}/terraform.tfstate"
    region = var.aws_region
  }
}

data "aws_caller_identity" "current" {}

################################################################################
# SNS Topics for Alerts
################################################################################

module "sns_alerts" {
  source = "../../../modules/sns"
  count  = var.enable_sns_alerts ? 1 : 0

  topic_name   = "${var.project_name}-${var.environment}-alerts"
  display_name = "Alerts for ${var.environment} environment"

  # Subscriptions
  subscriptions = var.alert_email != "" ? {
    email = {
      protocol = "email"
      endpoint = var.alert_email
    }
  } : {}

  # Encryption
  kms_master_key_id = try(data.terraform_remote_state.security.outputs.kms_key_arn, null)

  tags = var.common_tags
}

module "sns_critical" {
  source = "../../../modules/sns"
  count  = var.enable_critical_alerts ? 1 : 0

  topic_name   = "${var.project_name}-${var.environment}-critical"
  display_name = "Critical alerts for ${var.environment} environment"

  # Subscriptions
  subscriptions = var.critical_alert_email != "" ? {
    email = {
      protocol = "email"
      endpoint = var.critical_alert_email
    }
  } : {}

  kms_master_key_id = try(data.terraform_remote_state.security.outputs.kms_key_arn, null)

  tags = merge(var.common_tags, {
    AlertLevel = "critical"
  })
}

################################################################################
# CloudWatch Monitoring
################################################################################

module "cloudwatch" {
  source = "../../../modules/cloudwatch"

  # Default configuration
  default_log_retention_days = var.default_log_retention_days
  default_kms_key_id         = var.enable_log_encryption ? try(data.terraform_remote_state.security.outputs.kms_key_arn, null) : null

  # Log Groups
  log_groups = merge(
    # Application log groups
    var.application_log_groups,
    
    # Standard log groups
    var.create_standard_log_groups ? {
      application = {
        name              = "/aws/application/${var.project_name}-${var.environment}"
        retention_in_days = var.default_log_retention_days
        kms_key_id        = var.enable_log_encryption ? try(data.terraform_remote_state.security.outputs.kms_key_arn, null) : null
      }
      
      lambda = {
        name              = "/aws/lambda/${var.project_name}-${var.environment}"
        retention_in_days = var.lambda_log_retention_days
        kms_key_id        = var.enable_log_encryption ? try(data.terraform_remote_state.security.outputs.kms_key_arn, null) : null
      }
      
      ecs = {
        name              = "/aws/ecs/${var.project_name}-${var.environment}"
        retention_in_days = var.ecs_log_retention_days
        kms_key_id        = var.enable_log_encryption ? try(data.terraform_remote_state.security.outputs.kms_key_arn, null) : null
      }
    } : {}
  )

  # Log Metric Filters
  log_metric_filters = var.log_metric_filters

  # Metric Alarms
  metric_alarms = merge(
    var.metric_alarms,
    
    # Standard infrastructure alarms
    var.create_standard_alarms ? {
      # Add standard alarms based on environment
    } : {}
  )

  # Composite Alarms
  composite_alarms = var.composite_alarms

  # Dashboards
  dashboards = var.dashboards

  # Query Definitions
  query_definitions = var.query_definitions

  # Anomaly Detectors
  anomaly_detectors = var.anomaly_detectors

  tags = var.common_tags
}

################################################################################
# Standard Metric Alarms (Optional)
################################################################################

# These can be enabled via variable configuration
# Examples are in the environment tfvars files

################################################################################
# Store Outputs in SSM Parameter Store
################################################################################

module "ssm_outputs" {
  source = "../../../modules/ssm-outputs"

  project_name = var.project_name
  environment  = var.environment
  layer_name   = "monitoring"

  outputs = {
    # SNS Topics
    sns_alerts_topic_arn    = var.enable_sns_alerts ? module.sns_alerts[0].topic_arn : null
    sns_alerts_topic_name   = var.enable_sns_alerts ? module.sns_alerts[0].topic_name : null
    sns_critical_topic_arn  = var.enable_critical_alerts ? module.sns_critical[0].topic_arn : null
    sns_critical_topic_name = var.enable_critical_alerts ? module.sns_critical[0].topic_name : null
    
    # Log Groups
    log_group_names = jsonencode(module.cloudwatch.log_group_names)
    log_group_arns  = jsonencode(module.cloudwatch.log_group_arns)
    
    # Alarms
    metric_alarm_names = jsonencode(module.cloudwatch.metric_alarm_names)
    metric_alarm_arns  = jsonencode(module.cloudwatch.metric_alarm_arns)
    
    # Dashboards
    dashboard_names = jsonencode(module.cloudwatch.dashboard_names)
    
    # Summary
    monitoring_summary = jsonencode(module.cloudwatch.monitoring_summary)
  }

  output_descriptions = {
    sns_alerts_topic_arn    = "SNS topic ARN for general alerts"
    sns_alerts_topic_name   = "SNS topic name for general alerts"
    sns_critical_topic_arn  = "SNS topic ARN for critical alerts"
    sns_critical_topic_name = "SNS topic name for critical alerts"
    log_group_names         = "Map of CloudWatch log group names"
    log_group_arns          = "Map of CloudWatch log group ARNs"
    metric_alarm_names      = "Map of CloudWatch alarm names"
    metric_alarm_arns       = "Map of CloudWatch alarm ARNs"
    dashboard_names         = "Map of CloudWatch dashboard names"
    monitoring_summary      = "Summary of monitoring resources"
  }

  tags = var.common_tags

  depends_on = [
    module.sns_alerts,
    module.sns_critical,
    module.cloudwatch
  ]
}
