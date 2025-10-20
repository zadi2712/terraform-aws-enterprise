# Security Layer - UAT Environment Configuration
# Version: 2.0 - Enhanced KMS configuration

aws_region   = "us-east-1"
environment  = "uat"
project_name = "mycompany"

common_tags = {
  Environment = "uat"
  Project     = "mycompany"
  ManagedBy   = "terraform"
  Layer       = "security"
  CostCenter  = "engineering"
  Compliance  = "required"
}

################################################################################
# KMS Configuration
################################################################################

# Main KMS key for general encryption
kms_main_description        = "UAT environment main encryption key"
kms_deletion_window_in_days = 30  # Full window for UAT (production-like)
kms_enable_key_rotation     = true
kms_rotation_period_in_days = 365

# Key access control (update with actual IAM ARNs)
kms_key_administrators = [
  # "arn:aws:iam::ACCOUNT_ID:role/SecurityAdmin",
  # "arn:aws:iam::ACCOUNT_ID:role/PlatformAdmin"
]

kms_key_users = [
  # "arn:aws:iam::ACCOUNT_ID:role/UATTeamRole",
  # "arn:aws:iam::ACCOUNT_ID:role/ApplicationRole"
]

# Service principals that can use the key
kms_service_principals = [
  "logs.amazonaws.com",
  "s3.amazonaws.com",
  "ec2.amazonaws.com",
  "rds.amazonaws.com",
  "ecs.amazonaws.com"
]

kms_via_service_conditions = [
  "logs.us-east-1.amazonaws.com",
  "s3.us-east-1.amazonaws.com",
  "ec2.us-east-1.amazonaws.com",
  "rds.us-east-1.amazonaws.com",
  "ecs.us-east-1.amazonaws.com"
]

# Enable CloudWatch Logs encryption
kms_enable_cloudwatch_logs = true

# Enable grant permissions for AWS services
kms_enable_grant_permissions = true

################################################################################
# Service-Specific KMS Keys
################################################################################

# Production-like configuration with dedicated keys
create_rds_key = true  # Dedicated key for RDS
create_s3_key  = true  # Dedicated key for S3
create_ebs_key = true  # Enable default EBS encryption
