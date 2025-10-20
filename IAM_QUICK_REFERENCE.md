# IAM Quick Reference

## 🚀 Quick Start

### Deploy Cross-Account Role

```bash
cd layers/security/environments/prod

# Edit terraform.tfvars
enable_cross_account_roles = true

# Add role configuration (see templates below)

# Deploy
terraform init -backend-config=backend.conf -upgrade
terraform apply

# Get role ARN
terraform output iam_role_arns
```

### Deploy GitHub Actions OIDC

```bash
cd layers/security/environments/prod

# Enable OIDC
enable_oidc_providers = true

# Already configured in prod terraform.tfvars!

terraform apply

# Get role ARN for GitHub secrets
terraform output iam_role_arns | jq -r '.github_deploy_prod'
```

---

## 📋 Common Commands

### AWS CLI - Roles

```bash
# List roles
aws iam list-roles

# Get role details
aws iam get-role --role-name MyRole

# Get role trust policy
aws iam get-role --role-name MyRole \
  --query 'Role.AssumeRolePolicyDocument'

# List attached policies
aws iam list-attached-role-policies --role-name MyRole

# List inline policies
aws iam list-role-policies --role-name MyRole

# Delete role
aws iam delete-role --role-name MyRole
```

### AWS CLI - Assume Role

```bash
# Assume role
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/MyRole \
  --role-session-name my-session \
  --external-id unique-external-id

# Assume role with MFA
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/MyRole \
  --role-session-name my-session \
  --serial-number arn:aws:iam::123456789012:mfa/user \
  --token-code 123456

# Use assumed role credentials
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
```

### AWS CLI - Policies

```bash
# List customer managed policies
aws iam list-policies --scope Local

# Get policy details
aws iam get-policy --policy-arn arn:aws:iam::123456789012:policy/MyPolicy

# Get policy version
aws iam get-policy-version \
  --policy-arn arn:aws:iam::123456789012:policy/MyPolicy \
  --version-id v1

# Simulate policy
aws iam simulate-custom-policy \
  --policy-input-list file://policy.json \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::mybucket/*
```

### AWS CLI - OIDC Providers

```bash
# List OIDC providers
aws iam list-open-id-connect-providers

# Get OIDC provider details
aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com

# Delete OIDC provider
aws iam delete-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com
```

### Terraform Commands

```bash
# Get outputs
terraform output iam_role_arns
terraform output iam_policy_arns
terraform output oidc_provider_arns
terraform output iam_summary

# Enable cross-account roles
# Edit terraform.tfvars: enable_cross_account_roles = true
terraform apply

# Update role
# Edit role configuration in terraform.tfvars
terraform apply
```

---

## 🎯 Configuration Templates

### Cross-Account Audit Role

```hcl
# In terraform.tfvars

enable_cross_account_roles = true

iam_roles = {
  audit = {
    name = "CrossAccountAudit"
    
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          AWS = "arn:aws:iam::AUDIT_ACCOUNT_ID:root"
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "GENERATED_EXTERNAL_ID"
          }
        }
      }]
    })
    
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/SecurityAudit",
      "arn:aws:iam::aws:policy/ViewOnlyAccess"
    ]
    
    max_session_duration = 43200
  }
}
```

### GitHub Actions Role

```hcl
enable_oidc_providers = true

oidc_providers = {
  github = {
    url            = "https://token.actions.githubusercontent.com"
    client_id_list = ["sts.amazonaws.com"]
    thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  }
}

iam_roles = {
  github_ci = {
    name = "GitHubActions"
    
    assume_role_policy = jsonencode({
      Statement = [{
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:ORG/REPO:*"
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

### Emergency Access Role

```hcl
iam_roles = {
  emergency = {
    name = "EmergencyAccess"
    
    assume_role_policy = jsonencode({
      Statement = [{
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::ACCOUNT_ID:user/admin1",
            "arn:aws:iam::ACCOUNT_ID:user/admin2"
          ]
        }
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }]
    })
    
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/AdministratorAccess"
    ]
    
    max_session_duration = 3600
  }
}
```

---

## 🔑 GitHub Actions Integration

### Workflow File

```yaml
name: Deploy
on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1
      
      - name: Deploy
        run: terraform apply -auto-approve
```

### Thumbprints

```
GitHub Actions:  6938fd4d98bab03faadb97b34396831e3780aea1
GitLab:          See GitLab documentation
CircleCI:        See CircleCI documentation
```

---

## 🛡️ Security Patterns

### Pattern: Least Privilege

```hcl
# ✅ Good - Specific permissions
managed_policy_arns = [
  "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
]

# ❌ Bad - Too broad
managed_policy_arns = [
  "arn:aws:iam::aws:policy/AdministratorAccess"
]
```

### Pattern: Time-Limited Access

```hcl
# Short session for automation
max_session_duration = 1800  # 30 minutes

# Longer for human interactive
max_session_duration = 28800  # 8 hours
```

### Pattern: Conditional Access

```hcl
Condition = {
  # Require MFA
  Bool = {
    "aws:MultiFactorAuthPresent" = "true"
  }
  
  # Restrict IP
  IpAddress = {
    "aws:SourceIp" = ["203.0.113.0/24"]
  }
  
  # Require encryption
  StringEquals = {
    "s3:x-amz-server-side-encryption" = "aws:kms"
  }
}
```

---

## 🔍 Useful Queries

### Find Unused Roles

```bash
# Get last used time for roles
aws iam generate-credential-report
sleep 5
aws iam get-credential-report --query 'Content' --output text | base64 -d > report.csv

# Parse for unused roles
grep -v "N/A" report.csv | awk -F, '{if ($11 == "N/A") print $1}'
```

### List Roles by Service

```bash
# Roles for specific service
aws iam list-roles --query 'Roles[?contains(AssumeRolePolicyDocument.Statement[0].Principal.Service, `ec2`)].[RoleName]' --output table
```

### Check Policy Permissions

```bash
# Simulate what a role can do
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/MyRole \
  --action-names s3:PutObject s3:GetObject \
  --resource-arns arn:aws:s3:::mybucket/*
```

---

## 🆘 Emergency Procedures

### Assume Emergency Role

```bash
# 1. Get MFA token code (from authenticator app)

# 2. Assume role with MFA
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/EmergencyAccess \
  --role-session-name emergency-$(date +%s) \
  --serial-number arn:aws:iam::123456789012:mfa/your-user \
  --token-code 123456

# 3. Export credentials
# (use output from above)
```

### Revoke All Sessions

```bash
# Attach deny-all policy
aws iam put-role-policy \
  --role-name CompromisedRole \
  --policy-name DenyAll \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Deny","Action":"*","Resource":"*"}]}'

# Or delete role (after detaching policies)
aws iam delete-role --role-name CompromisedRole
```

---

## 💡 Pro Tips

### 1. Generate External IDs

```bash
# Secure random string
openssl rand -base64 32

# Or
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

### 2. Test IAM Policies

```bash
# Use IAM Policy Simulator
https://policysim.aws.amazon.com/

# Or CLI
aws iam simulate-custom-policy \
  --policy-input-list file://policy.json \
  --action-names ec2:RunInstances \
  --resource-arns "*"
```

### 3. Use AWS CLI Profiles

```ini
# ~/.aws/config

[profile cross-account]
role_arn = arn:aws:iam::TARGET_ACCOUNT:role/CrossAccountAccess
source_profile = default
external_id = your-external-id
region = us-east-1

[profile github-ci]
role_arn = arn:aws:iam::123456789012:role/GitHubActions
web_identity_token_file = /path/to/token
```

### 4. Audit Role Usage

```bash
# CloudTrail events for AssumeRole
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRole \
  --max-results 50
```

---

## 📚 Additional Resources

- [IAM Module README](modules/iam/README.md)
- [IAM Deployment Guide](IAM_DEPLOYMENT_GUIDE.md)
- [Architecture Decision](ARCHITECTURE_DECISION_IAM.md)
- [AWS IAM Documentation](https://docs.aws.amazon.com/iam/)

---

## 🎯 Quick Decisions

### Do I need the IAM module?

```
Is it for cross-account access?           → YES, use IAM module
Is it for GitHub Actions?                 → YES, use IAM module
Is it for SSO/SAML?                       → YES, use IAM module
Is it organization-wide?                  → YES, use IAM module

Is it for ECS tasks?                      → NO, use ECS module
Is it for Lambda functions?               → NO, use Lambda module
Is it for EC2 instances?                  → NO, use EC2 module
Is it for a specific service?             → NO, use that service's module
```

---

**IAM Quick Reference v2.0**

