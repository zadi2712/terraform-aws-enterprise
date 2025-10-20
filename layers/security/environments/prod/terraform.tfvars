# Security Layer - Production Environment Configuration
# Version: 2.0 - Enhanced KMS configuration

aws_region   = "us-east-1"
environment  = "prod"
project_name = "mycompany"

common_tags = {
  Environment = "prod"
  Project     = "mycompany"
  ManagedBy   = "terraform"
  Layer       = "security"
  CostCenter  = "engineering"
  Compliance  = "required"
  DataClass   = "confidential"
}

################################################################################
# KMS Configuration - Production
################################################################################

# Main KMS key for general encryption
kms_main_description        = "Production environment main encryption key"
kms_deletion_window_in_days = 30  # Maximum window for production
kms_enable_key_rotation     = true
kms_rotation_period_in_days = 365  # Annual rotation

# Key access control (update with actual IAM ARNs)
# IMPORTANT: Restrict to specific roles in production
kms_key_administrators = [
  # "arn:aws:iam::ACCOUNT_ID:role/SecurityAdmin",
  # "arn:aws:iam::ACCOUNT_ID:role/ComplianceAdmin"
]

kms_key_users = [
  # "arn:aws:iam::ACCOUNT_ID:role/ProductionApplicationRole",
  # "arn:aws:iam::ACCOUNT_ID:role/ECSTaskRole",
  # "arn:aws:iam::ACCOUNT_ID:role/LambdaExecutionRole"
]

# Service principals that can use the key
kms_service_principals = [
  "logs.amazonaws.com",
  "s3.amazonaws.com",
  "ec2.amazonaws.com",
  "rds.amazonaws.com",
  "ecs.amazonaws.com",
  "secretsmanager.amazonaws.com"
]

kms_via_service_conditions = [
  "logs.us-east-1.amazonaws.com",
  "s3.us-east-1.amazonaws.com",
  "ec2.us-east-1.amazonaws.com",
  "rds.us-east-1.amazonaws.com",
  "ecs.us-east-1.amazonaws.com",
  "secretsmanager.us-east-1.amazonaws.com"
]

# Enable CloudWatch Logs encryption
kms_enable_cloudwatch_logs = true

# Enable grant permissions for AWS services
kms_enable_grant_permissions = true

################################################################################
# Service-Specific KMS Keys - Production Best Practice
################################################################################

# Production best practice: Dedicated keys for each service
# Provides better security isolation and audit capabilities

create_rds_key = true  # Dedicated key for RDS databases
create_s3_key  = true  # Dedicated key for S3 buckets
create_ebs_key = true  # Enable default EBS volume encryption

# Additional considerations for production:
# - Review and update IAM ARNs above before deployment
# - Enable CloudTrail logging for all KMS operations
# - Set up CloudWatch alarms for key usage
# - Implement key rotation monitoring
# - Regular access audits and policy reviews
# - Document key purposes and owners
# - Backup key policies and configurations
