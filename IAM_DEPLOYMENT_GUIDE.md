# IAM Deployment Guide

## Overview

Complete guide for managing cross-cutting IAM concerns including cross-account roles, OIDC/SAML providers, and organization-wide policies using the enterprise Terraform IAM module.

**Version:** 2.0  
**Last Updated:** October 20, 2025  
**Status:** ✅ Production Ready

**⚠️ IMPORTANT:** This module is for **cross-cutting IAM only**. Service-specific IAM (ECS tasks, Lambda functions, EC2 instances) should be managed by their respective modules. See [ARCHITECTURE_DECISION_IAM.md](ARCHITECTURE_DECISION_IAM.md).

---

## Table of Contents

1. [When to Use This Module](#when-to-use-this-module)
2. [Prerequisites](#prerequisites)
3. [Deployment Steps](#deployment-steps)
4. [Common Patterns](#common-patterns)
5. [GitHub Actions Integration](#github-actions-integration)
6. [Cross-Account Access](#cross-account-access)
7. [SSO Integration](#sso-integration)
8. [Security Best Practices](#security-best-practices)
9. [Troubleshooting](#troubleshooting)

---

## When to Use This Module

### ✅ USE IAM Module For:

1. **Cross-Account Access Roles**
   - Audit account access
   - Security scanning roles
   - Backup account access
   - Organization-wide roles

2. **CI/CD Integration**
   - GitHub Actions OIDC provider and roles
   - GitLab CI/CD integration
   - Jenkins pipeline roles

3. **SSO Integration**
   - SAML providers for Okta, Azure AD, etc.
   - SSO-assumed roles

4. **Organization-Wide Policies**
   - Compliance policies
   - Security guardrails
   - Cost control policies

5. **Emergency Access**
   - Break-glass roles
   - Incident response roles

6. **IAM Groups/Users** (when SSO not available)
   - Development accounts
   - Legacy systems

### ❌ DON'T USE IAM Module For:

1. ❌ ECS task execution roles → Use ECS module
2. ❌ Lambda execution roles → Use Lambda module
3. ❌ EC2 instance profiles → Use EC2 module
4. ❌ RDS service roles → Use RDS module
5. ❌ Service-specific IAM → Module-owned

**Why?** Better encapsulation, flexibility, and no naming conflicts.

---

## Prerequisites

### Required Infrastructure

- Security layer deployed (KMS for encryption)
- Terraform >= 1.13.0
- AWS CLI v2

### Required Information

For cross-account roles:
- Target AWS account IDs
- External IDs (generate unique random strings)

For OIDC providers:
- Provider URLs
- Thumbprints (GitHub: `6938fd4d98bab03faadb97b34396831e3780aea1`)

---

## Deployment Steps

### Step 1: Choose Your Use Case

Determine which IAM features you need:

```hcl
# In layers/security/environments/prod/terraform.tfvars

enable_cross_account_roles = true   # For audit/security accounts
enable_oidc_providers      = true   # For GitHub Actions, GitLab
enable_iam_groups          = false  # Prefer AWS SSO
```

### Step 2: Configure IAM Resources

#### Example: GitHub Actions Integration

```hcl
# 1. Create OIDC provider
oidc_providers = {
  github = {
    url            = "https://token.actions.githubusercontent.com"
    client_id_list = ["sts.amazonaws.com"]
    thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  }
}

# 2. Create role for GitHub Actions
iam_roles = {
  github_deploy = {
    name = "GitHubActionsDeploy"
    
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:myorg/myrepo:*"
          }
        }
      }]
    })
    
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/PowerUserAccess"
    ]
  }
}
```

### Step 3: Deploy

```bash
cd layers/security/environments/prod
terraform init -backend-config=backend.conf -upgrade
terraform plan
terraform apply
```

### Step 4: Get Role ARNs

```bash
# Get all role ARNs
terraform output iam_role_arns

# Get specific role
terraform output iam_role_arns | jq -r '.github_deploy'
```

### Step 5: Use in GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsDeploy
          aws-region: us-east-1
      
      - name: Deploy
        run: |
          terraform init
          terraform apply -auto-approve
```

---

## Common Patterns

### Pattern 1: Cross-Account Audit Role

```hcl
iam_roles = {
  audit_access = {
    name        = "AuditAccountAccess"
    description = "Allows audit account to review resources"
    
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          AWS = "arn:aws:iam::987654321098:root"  # Audit account
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "randomly-generated-unique-id"
          }
        }
      }]
    })
    
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/SecurityAudit",
      "arn:aws:iam::aws:policy/ViewOnlyAccess"
    ]
    
    max_session_duration = 43200  # 12 hours
  }
}
```

### Pattern 2: GitHub Actions with Repository Restriction

```hcl
# OIDC Provider
oidc_providers = {
  github = {
    url            = "https://token.actions.githubusercontent.com"
    client_id_list = ["sts.amazonaws.com"]
    thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  }
}

# Role with strict repository and branch restrictions
iam_roles = {
  github_prod_deploy = {
    name = "GitHubProdDeploy"
    
    assume_role_policy = jsonencode({
      Statement = [{
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:myorg/myrepo:ref:refs/heads/main"
          }
        }
      }]
    })
    
    managed_policy_arns = ["arn:aws:iam::aws:policy/PowerUserAccess"]
    max_session_duration = 1800  # 30 minutes for security
  }
}
```

### Pattern 3: Organization-Wide Compliance Policy

```hcl
iam_policies = {
  enforce_encryption = {
    name        = "EnforceEncryption"
    description = "Deny unencrypted S3 uploads"
    
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Deny"
        Action = ["s3:PutObject"]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }]
    })
  }
  
  require_mfa = {
    name        = "RequireMFA"
    description = "Deny actions without MFA"
    
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:ResyncMFADevice",
          "sts:GetSessionToken"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }]
    })
  }
}
```

### Pattern 4: Break-Glass Emergency Access

```hcl
iam_roles = {
  emergency = {
    name        = "EmergencyAccess"
    description = "Emergency administrator access with MFA"
    
    assume_role_policy = jsonencode({
      Statement = [{
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::ACCOUNT_ID:user/cto",
            "arn:aws:iam::ACCOUNT_ID:user/security.lead"
          ]
        }
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"  # Requires MFA
          }
          IpAddress = {
            "aws:SourceIp" = ["203.0.113.0/24"]  # Office IP only
          }
        }
      }]
    })
    
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/AdministratorAccess"
    ]
    
    max_session_duration = 3600  # 1 hour maximum
  }
}
```

---

## GitHub Actions Integration

### Complete Setup

#### 1. Create OIDC Provider + Role (Terraform)

Already configured in UAT/Prod terraform.tfvars!

#### 2. Update GitHub Workflow

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  id-token: write  # Required for OIDC
  contents: read

jobs:
  terraform:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1
          role-session-name: GitHubActions-${{ github.run_id }}
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.13.4
      
      - name: Terraform Init
        run: |
          cd layers/compute/environments/prod
          terraform init -backend-config=backend.conf
      
      - name: Terraform Plan
        run: |
          cd layers/compute/environments/prod
          terraform plan
      
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: |
          cd layers/compute/environments/prod
          terraform apply -auto-approve
```

#### 3. Add Secret to GitHub

```bash
# Get role ARN
cd layers/security/environments/prod
ROLE_ARN=$(terraform output iam_role_arns | jq -r '.github_deploy_prod')

# Add to GitHub secrets:
# Settings → Secrets → Actions → New repository secret
# Name: AWS_ROLE_ARN
# Value: <paste ROLE_ARN>
```

---

## Cross-Account Access

### Setup Guide

#### 1. In Target Account (Being Accessed)

```hcl
# layers/security/environments/prod/terraform.tfvars

iam_roles = {
  cross_account = {
    name = "CrossAccountAccess"
    
    assume_role_policy = jsonencode({
      Statement = [{
        Principal = {
          AWS = "arn:aws:iam::SOURCE_ACCOUNT_ID:root"
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "unique-external-id-2024"
          }
        }
      }]
    })
    
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/ReadOnlyAccess"
    ]
  }
}
```

#### 2. In Source Account (Assuming Role)

Users in source account need permission to assume the role:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "sts:AssumeRole",
    "Resource": "arn:aws:iam::TARGET_ACCOUNT:role/CrossAccountAccess"
  }]
}
```

#### 3. Assume the Role

```bash
# Assume role
aws sts assume-role \
  --role-arn arn:aws:iam::TARGET_ACCOUNT:role/CrossAccountAccess \
  --role-session-name audit-session \
  --external-id unique-external-id-2024

# Or configure in AWS CLI profile
# ~/.aws/config
[profile cross-account]
role_arn = arn:aws:iam::TARGET_ACCOUNT:role/CrossAccountAccess
source_profile = default
external_id = unique-external-id-2024
```

---

## SSO Integration

### SAML Provider Setup

#### 1. Get SAML Metadata from IdP

```bash
# Download from Okta, Azure AD, etc.
# Usually: https://your-idp.com/app/metadata
```

#### 2. Configure in Terraform

```hcl
saml_providers = {
  corporate_sso = {
    name                   = "CorporateSSO"
    saml_metadata_document = file("${path.module}/saml-metadata.xml")
  }
}

iam_roles = {
  sso_admin = {
    name = "SSOAdministrator"
    
    assume_role_policy = jsonencode({
      Statement = [{
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::ACCOUNT_ID:saml-provider/CorporateSSO"
        }
        Action = "sts:AssumeRoleWithSAML"
        Condition = {
          StringEquals = {
            "SAML:aud" = "https://signin.aws.amazon.com/saml"
          }
        }
      }]
    })
    
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/AdministratorAccess"
    ]
  }
  
  sso_developer = {
    name = "SSODeveloper"
    
    assume_role_policy = jsonencode({
      Statement = [{
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::ACCOUNT_ID:saml-provider/CorporateSSO"
        }
        Action = "sts:AssumeRoleWithSAML"
        Condition = {
          StringEquals = {
            "SAML:aud" = "https://signin.aws.amazon.com/saml"
          }
        }
      }]
    })
    
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/PowerUserAccess"
    ]
  }
}
```

---

## Security Best Practices

### 1. Always Use External IDs

```hcl
Condition = {
  StringEquals = {
    "sts:ExternalId" = "randomly-generated-unique-string"
  }
}
```

**Generate External ID:**
```bash
# Linux/Mac
openssl rand -base64 32

# Or use UUIDv4
uuidgen
```

### 2. Limit Session Duration

```hcl
# Production: Short sessions
max_session_duration = 3600  # 1 hour

# Trusted roles: Longer sessions
max_session_duration = 43200  # 12 hours (max)
```

### 3. Require MFA for Sensitive Roles

```hcl
Condition = {
  Bool = {
    "aws:MultiFactorAuthPresent" = "true"
  }
}
```

### 4. Restrict Source IP

```hcl
Condition = {
  IpAddress = {
    "aws:SourceIp" = ["203.0.113.0/24"]  # Office network only
  }
}
```

### 5. Use Permissions Boundaries

```hcl
roles = {
  developer = {
    permissions_boundary = "arn:aws:iam::aws:policy/PowerUserAccess"
    # Prevents privilege escalation
  }
}
```

### 6. Configure Strong Password Policy

```hcl
configure_password_policy = true

password_policy = {
  minimum_password_length      = 16  # Strong
  require_symbols              = true
  max_password_age             = 90
  password_reuse_prevention    = 24
}
```

---

## Monitoring & Auditing

### CloudTrail Logging

All IAM operations are automatically logged to CloudTrail.

```bash
# View recent IAM operations
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceType,AttributeValue=AWS::IAM::Role \
  --max-results 10
```

### IAM Access Analyzer

```bash
# Enable IAM Access Analyzer (per region)
aws accessanalyzer create-analyzer \
  --analyzer-name production-analyzer \
  --type ACCOUNT

# List findings
aws accessanalyzer list-findings \
  --analyzer-arn arn:aws:access-analyzer:us-east-1:123456789012:analyzer/production-analyzer
```

### Regular Audits

```bash
# List all roles
aws iam list-roles

# Get role details
aws iam get-role --role-name CrossAccountAccess

# List attached policies
aws iam list-attached-role-policies --role-name CrossAccountAccess

# Review trust policy
aws iam get-role --role-name CrossAccountAccess \
  --query 'Role.AssumeRolePolicyDocument'
```

---

## Troubleshooting

### Issue: AssumeRole Access Denied

**Check Trust Policy:**
```bash
aws iam get-role --role-name MyRole \
  --query 'Role.AssumeRolePolicyDocument'
```

**Common Causes:**
1. Missing or incorrect External ID
2. Source principal not allowed
3. MFA required but not provided
4. IP restriction

**Test AssumeRole:**
```bash
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/MyRole \
  --role-session-name test \
  --external-id your-external-id
```

### Issue: GitHub Actions OIDC Fails

**Verify OIDC Provider:**
```bash
aws iam list-open-id-connect-providers

aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com
```

**Check Trust Policy:**
```bash
aws iam get-role --role-name GitHubActionsDeploy \
  --query 'Role.AssumeRolePolicyDocument.Statement[0].Condition'
```

**Common Issues:**
1. Wrong thumbprint (use: `6938fd4d98bab03faadb97b34396831e3780aea1`)
2. Repository filter too strict
3. Missing `id-token: write` permission in workflow

### Issue: Password Policy Not Applied

```bash
# Check current password policy
aws iam get-account-password-policy

# If error: Policy not set
# Verify configure_password_policy = true in terraform.tfvars
```

---

## Best Practices Checklist

### Before Deployment

- [ ] Determine if IAM module is needed (vs module-owned IAM)
- [ ] Generate unique external IDs
- [ ] Document all roles and their purposes
- [ ] Review AWS account IDs
- [ ] Verify OIDC thumbprints
- [ ] Plan session durations

### After Deployment

- [ ] Test cross-account access
- [ ] Verify OIDC authentication works
- [ ] Document role ARNs
- [ ] Set up CloudWatch alarms for IAM operations
- [ ] Enable IAM Access Analyzer
- [ ] Schedule regular access reviews

### Ongoing

- [ ] Review IAM policies quarterly
- [ ] Rotate external IDs annually
- [ ] Audit role usage
- [ ] Remove unused roles
- [ ] Update documentation

---

## References

- [IAM Module README](modules/iam/README.md)
- [Architecture Decision: IAM](ARCHITECTURE_DECISION_IAM.md)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [OIDC Providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [Cross-Account Access](https://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html)

---

**End of Deployment Guide**

