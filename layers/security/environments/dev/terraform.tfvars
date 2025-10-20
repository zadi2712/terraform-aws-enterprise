# Security Layer - Development Environment Configuration
# Version: 2.0 - Enhanced KMS configuration

aws_region   = "us-east-1"
environment  = "dev"
project_name = "mycompany"

common_tags = {
  Environment = "dev"
  Project     = "mycompany"
  ManagedBy   = "terraform"
  Layer       = "security"
  CostCenter  = "engineering"
}

################################################################################
# KMS Configuration
################################################################################

# Main KMS key for general encryption
kms_main_description        = "Development environment main encryption key"
kms_deletion_window_in_days = 7  # Shorter window for dev
kms_enable_key_rotation     = true
kms_rotation_period_in_days = 365

# Key access control (update with actual IAM ARNs)
kms_key_administrators = [
  # "arn:aws:iam::ACCOUNT_ID:role/SecurityAdmin",
  # "arn:aws:iam::ACCOUNT_ID:role/PlatformAdmin"
]

kms_key_users = [
  # "arn:aws:iam::ACCOUNT_ID:role/DeveloperRole",
  # "arn:aws:iam::ACCOUNT_ID:role/ApplicationRole"
]

# Service principals that can use the key
kms_service_principals = [
  "logs.amazonaws.com",
  "s3.amazonaws.com",
  "ec2.amazonaws.com"
]

kms_via_service_conditions = [
  "logs.us-east-1.amazonaws.com",
  "s3.us-east-1.amazonaws.com",
  "ec2.us-east-1.amazonaws.com"
]

# Enable CloudWatch Logs encryption
kms_enable_cloudwatch_logs = true

# Enable grant permissions for AWS services
kms_enable_grant_permissions = true

################################################################################
# Service-Specific KMS Keys (Optional)
################################################################################

# Create separate keys for specific services
# Recommended for development: false (use main key to save costs)
create_rds_key = false  # Set to true if you use RDS in dev
create_s3_key  = false  # Set to true if you need separate S3 key
create_ebs_key = false  # Set to true to enable default EBS encryption
