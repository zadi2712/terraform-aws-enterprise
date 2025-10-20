# KMS Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying and managing AWS KMS (Key Management Service) encryption keys using the enterprise Terraform infrastructure.

**Version:** 2.0  
**Last Updated:** October 20, 2025  
**Status:** ✅ Production Ready

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Deployment Steps](#deployment-steps)
4. [Configuration Options](#configuration-options)
5. [Post-Deployment](#post-deployment)
6. [Security Best Practices](#security-best-practices)
7. [Monitoring & Auditing](#monitoring--auditing)
8. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### KMS Module Structure

```
modules/kms/
├── main.tf          # KMS key, alias, grants, and policies
├── variables.tf     # Comprehensive configuration options
├── outputs.tf       # Key information and metadata
├── versions.tf      # Provider requirements
└── README.md        # Module documentation
```

### Security Layer Integration

```
layers/security/
├── main.tf          # Multiple KMS keys (main, RDS, S3, EBS)
├── variables.tf     # Layer-specific configuration
├── outputs.tf       # Exposed key information
└── environments/
    ├── dev/
    ├── qa/
    ├── uat/
    └── prod/
```

### Key Hierarchy

```
┌─────────────────────────────────────┐
│         AWS Account Root            │
└─────────────────────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
┌───────▼────────┐  ┌──────▼────────┐
│   Main Key     │  │ Service Keys  │
│  (General)     │  │  (Specific)   │
└────────────────┘  └───────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    ┌────▼────┐      ┌────▼────┐      ┌────▼────┐
    │ RDS Key │      │ S3 Key  │      │ EBS Key │
    └─────────┘      └─────────┘      └─────────┘
```

---

## Prerequisites

### Required Tools

- **Terraform** >= 1.5.0
- **AWS CLI** v2
- **jq** (for JSON processing)

### AWS Permissions

Your AWS credentials must have the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:CreateKey",
        "kms:CreateAlias",
        "kms:DescribeKey",
        "kms:GetKeyPolicy",
        "kms:PutKeyPolicy",
        "kms:EnableKeyRotation",
        "kms:ListAliases",
        "kms:TagResource",
        "kms:CreateGrant"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:ListRolePolicies",
        "iam:GetRolePolicy"
      ],
      "Resource": "*"
    }
  ]
}
```

### Backend Setup

Ensure S3 backend is configured:

```bash
# Verify backend bucket exists
aws s3 ls s3://terraform-state-${ENVIRONMENT}-$(aws sts get-caller-identity --query Account --output text)
```

---

## Deployment Steps

### Step 1: Review Configuration

Edit the appropriate environment file:

```bash
cd layers/security/environments/dev
vi terraform.tfvars
```

Update the following sections:

#### A. IAM Access Control

```hcl
kms_key_administrators = [
  "arn:aws:iam::123456789012:role/SecurityAdmin",
  "arn:aws:iam::123456789012:role/PlatformAdmin"
]

kms_key_users = [
  "arn:aws:iam::123456789012:role/ApplicationRole",
  "arn:aws:iam::123456789012:role/ECSTaskRole"
]
```

**Important:** Replace `123456789012` with your AWS account ID:

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo $AWS_ACCOUNT_ID
```

#### B. Service Principals

```hcl
kms_service_principals = [
  "logs.amazonaws.com",
  "s3.amazonaws.com",
  "rds.amazonaws.com"
]

kms_via_service_conditions = [
  "logs.us-east-1.amazonaws.com",
  "s3.us-east-1.amazonaws.com",
  "rds.us-east-1.amazonaws.com"
]
```

#### C. Service-Specific Keys

```hcl
# Development
create_rds_key = false
create_s3_key  = false
create_ebs_key = false

# Production
create_rds_key = true
create_s3_key  = true
create_ebs_key = true
```

### Step 2: Initialize Terraform

```bash
cd layers/security/environments/dev
terraform init -backend-config=backend.conf
```

Expected output:
```
Initializing the backend...
Initializing modules...
Initializing provider plugins...
Terraform has been successfully initialized!
```

### Step 3: Validate Configuration

```bash
# Format check
terraform fmt -check -recursive

# Validate syntax
terraform validate

# Review plan
terraform plan
```

### Step 4: Deploy

```bash
# Deploy with approval
terraform apply

# Or auto-approve (CI/CD)
terraform apply -auto-approve
```

Expected resources created:
- Development: 1 KMS key
- QA: 2 KMS keys (main + EBS)
- UAT: 4 KMS keys (main + RDS + S3 + EBS)
- Production: 4 KMS keys (main + RDS + S3 + EBS)

### Step 5: Verify Deployment

```bash
# Get outputs
terraform output

# Verify main key
terraform output kms_key_id
terraform output kms_key_arn

# Check key details
aws kms describe-key --key-id $(terraform output -raw kms_key_id)
```

---

## Configuration Options

### Environment-Specific Settings

| Setting | Dev | QA | UAT | Prod |
|---------|-----|----|----|------|
| Deletion Window | 7 days | 14 days | 30 days | 30 days |
| Key Rotation | Enabled | Enabled | Enabled | Enabled |
| Rotation Period | 365 days | 365 days | 365 days | 365 days |
| RDS Key | Optional | Optional | Required | Required |
| S3 Key | Optional | Optional | Required | Required |
| EBS Key | Optional | Recommended | Required | Required |

### Key Rotation

```hcl
kms_enable_key_rotation     = true
kms_rotation_period_in_days = 365  # Annual rotation
```

Rotation periods must be between 90-2560 days.

### Custom Key Policy

If you need a custom policy:

```hcl
module "kms_custom" {
  source = "../../../modules/kms"

  key_name    = "custom-key"
  description = "Key with custom policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Your custom policy statements
    ]
  })
}
```

### Grants

For temporary permissions:

```hcl
module "kms_with_grants" {
  source = "../../../modules/kms"

  key_name = "key-with-grants"
  
  grants = {
    autoscaling = {
      grantee_principal = "arn:aws:iam::123456789012:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
      operations = ["Encrypt", "Decrypt", "GenerateDataKey", "CreateGrant"]
    }
  }
}
```

---

## Post-Deployment

### 1. Enable EBS Encryption by Default

If you created an EBS key:

```bash
# Get the EBS key ARN
EBS_KEY_ARN=$(terraform output -raw kms_ebs_key_arn)

# Set as default
aws ec2 modify-ebs-default-kms-key-id --kms-key-id $EBS_KEY_ARN

# Enable encryption by default
aws ec2 enable-ebs-encryption-by-default
```

### 2. Configure S3 Bucket Encryption

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = module.kms_s3[0].key_arn
    }
    bucket_key_enabled = true
  }
}
```

### 3. Configure RDS Encryption

```hcl
resource "aws_db_instance" "example" {
  # ... other configuration ...
  
  storage_encrypted = true
  kms_key_id        = module.kms_rds[0].key_arn
}
```

### 4. Update Application Configuration

Store key ARNs in SSM Parameter Store (automatically done):

```bash
# Retrieve key ARN
aws ssm get-parameter \
  --name "/mycompany/dev/security/kms_key_arn" \
  --query 'Parameter.Value' \
  --output text
```

---

## Security Best Practices

### 1. Principle of Least Privilege

**DO:**
```hcl
kms_key_users = [
  "arn:aws:iam::123456789012:role/SpecificApplicationRole"
]
```

**DON'T:**
```hcl
kms_key_users = [
  "arn:aws:iam::123456789012:root"  # Too broad!
]
```

### 2. Separate Administration from Usage

```hcl
kms_key_administrators = [
  "arn:aws:iam::123456789012:role/SecurityAdmin"  # Can manage key
]

kms_key_users = [
  "arn:aws:iam::123456789012:role/AppRole"  # Can only use key
]
```

### 3. Use Service-Specific Keys in Production

```hcl
# Production best practice
create_rds_key = true
create_s3_key  = true
create_ebs_key = true
```

Benefits:
- Better audit trails
- Easier compliance
- Reduced blast radius
- Service isolation

### 4. Enable Key Rotation

```hcl
kms_enable_key_rotation = true
```

AWS handles rotation automatically without downtime.

### 5. Use ViaService Conditions

```hcl
kms_service_principals = ["s3.amazonaws.com"]
kms_via_service_conditions = ["s3.us-east-1.amazonaws.com"]
```

Prevents direct key usage outside of specific services.

### 6. Tag Your Keys

```hcl
tags = {
  Environment = "production"
  Service     = "rds"
  DataClass   = "confidential"
  Owner       = "platform-team"
  Compliance  = "pci-dss"
}
```

---

## Monitoring & Auditing

### CloudTrail Logging

All KMS operations are logged to CloudTrail automatically.

View recent key operations:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=$(terraform output -raw kms_key_id) \
  --max-results 10
```

### CloudWatch Alarms

Create alarms for key operations:

```hcl
resource "aws_cloudwatch_metric_alarm" "kms_disable_alarm" {
  alarm_name          = "kms-key-disabled"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UserErrorCount"
  namespace           = "AWS/KMS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert when KMS key is disabled"
  
  dimensions = {
    KeyId = module.kms_main.key_id
  }
}
```

### Key Usage Monitoring

```bash
# Get key usage metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/KMS \
  --metric-name NumberOfDecryptCalls \
  --dimensions Name=KeyId,Value=$(terraform output -raw kms_key_id) \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum
```

### Audit Checklist

- [ ] Review key policies monthly
- [ ] Check key rotation status
- [ ] Audit key administrators and users
- [ ] Review CloudTrail logs
- [ ] Verify grants are still needed
- [ ] Check for unused keys
- [ ] Validate service principal permissions
- [ ] Review tags and update as needed

---

## Troubleshooting

### Issue: Access Denied Errors

**Symptoms:**
```
Error: AccessDeniedException: User is not authorized to perform: kms:Decrypt
```

**Solutions:**

1. **Check key policy:**
```bash
aws kms get-key-policy \
  --key-id $(terraform output -raw kms_key_id) \
  --policy-name default
```

2. **Verify IAM permissions:**
```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/YourRole \
  --action-names kms:Decrypt \
  --resource-arns $(terraform output -raw kms_key_arn)
```

3. **Check ViaService condition:**
```bash
# Ensure you're calling from the correct service
# Example: S3 must call KMS, not your application directly
```

### Issue: Key Not Rotating

**Check rotation status:**
```bash
aws kms get-key-rotation-status \
  --key-id $(terraform output -raw kms_key_id)
```

**Enable rotation:**
```bash
aws kms enable-key-rotation \
  --key-id $(terraform output -raw kms_key_id)
```

### Issue: Terraform Apply Fails

**Error:** `Key policy lockout`

**Solution:**
```hcl
# In emergency, bypass lockout check (USE WITH CAUTION)
bypass_policy_lockout_safety_check = true
```

**Better solution:** Ensure root account is in policy:
```hcl
kms_key_administrators = [
  "arn:aws:iam::123456789012:root",
  # ... other administrators
]
```

### Issue: Cannot Delete Key

KMS keys cannot be deleted immediately. They enter a deletion window.

**Check deletion status:**
```bash
aws kms describe-key --key-id YOUR_KEY_ID \
  --query 'KeyMetadata.DeletionDate'
```

**Cancel deletion:**
```bash
aws kms cancel-key-deletion --key-id YOUR_KEY_ID
```

---

## Upgrade Guide

### From Basic KMS to Enhanced Module

If you have existing inline KMS keys in the security layer:

1. **Export state:**
```bash
terraform state pull > backup.tfstate
```

2. **Import existing key:**
```bash
terraform import module.kms_main.aws_kms_key.this YOUR_EXISTING_KEY_ID
terraform import module.kms_main.aws_kms_alias.this[0] alias/YOUR_EXISTING_ALIAS
```

3. **Apply changes:**
```bash
terraform plan  # Review changes
terraform apply
```

---

## Additional Resources

- [KMS Module README](modules/kms/README.md)
- [KMS Quick Reference](KMS_QUICK_REFERENCE.md)
- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [AWS KMS Developer Guide](https://docs.aws.amazon.com/kms/latest/developerguide/)

---

## Support

For issues or questions:
1. Check this guide's [Troubleshooting](#troubleshooting) section
2. Review [KMS Quick Reference](KMS_QUICK_REFERENCE.md)
3. Check AWS CloudTrail logs
4. Review module documentation

---

**End of Deployment Guide**

