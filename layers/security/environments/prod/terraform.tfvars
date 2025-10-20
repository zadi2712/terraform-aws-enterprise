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

################################################################################
# IAM Configuration - Cross-Cutting Concerns (Production)
################################################################################

# Feature toggles
enable_cross_account_roles = true   # Enable for audit/security accounts
enable_oidc_providers      = true   # Enable for CI/CD
enable_iam_groups          = false  # Prefer AWS SSO for user management

# OIDC provider for GitHub Actions
oidc_providers = {
  github = {
    url            = "https://token.actions.githubusercontent.com"
    client_id_list = ["sts.amazonaws.com"]
    thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
    
    tags = {
      Purpose = "cicd"
    }
  }
}

# Cross-account and CI/CD roles
iam_roles = {
  # Cross-account audit role
  cross_account_audit = {
    name        = "CrossAccountAuditRole"
    description = "Read-only access from central audit account"
    
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          AWS = "arn:aws:iam::AUDIT_ACCOUNT_ID:root"  # Replace with audit account ID
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "prod-audit-external-id-2024"  # Unique per environment
          }
        }
      }]
    })
    
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/SecurityAudit",
      "arn:aws:iam::aws:policy/ViewOnlyAccess"
    ]
    
    max_session_duration = 43200  # 12 hours
    
    tags = {
      Purpose = "audit"
    }
  }
  
  # GitHub Actions deployment role
  github_deploy_prod = {
    name        = "GitHubActionsDeployProd"
    description = "Role for GitHub Actions to deploy to production"
    
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main"  # Only main branch
          }
        }
      }]
    })
    
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/PowerUserAccess"
    ]
    
    # Shorter session for production security
    max_session_duration = 1800  # 30 minutes
    
    tags = {
      Purpose = "cicd"
      Environment = "production"
    }
  }
  
  # Break-glass emergency role
  emergency_access = {
    name        = "EmergencyAccessRole"
    description = "Emergency access role for critical incidents"
    
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          AWS = [
            "arn:aws:iam::ACCOUNT_ID:user/emergency.user.1",
            "arn:aws:iam::ACCOUNT_ID:user/emergency.user.2"
          ]
        }
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"  # Require MFA
          }
        }
      }]
    })
    
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/AdministratorAccess"
    ]
    
    max_session_duration = 3600  # 1 hour max
    
    tags = {
      Purpose = "emergency"
      Critical = "true"
    }
  }
}

# Custom policies
iam_policies = {}

# SAML providers (if using SSO)
saml_providers = {}

# IAM groups (prefer AWS SSO)
iam_groups = {}

# IAM users (prefer AWS SSO)
iam_users = {}

# Password policy for production
configure_password_policy = true

password_policy = {
  minimum_password_length        = 16  # Stronger for production
  require_lowercase_characters   = true
  require_numbers                = true
  require_uppercase_characters   = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 24
  hard_expiry                    = false
}
