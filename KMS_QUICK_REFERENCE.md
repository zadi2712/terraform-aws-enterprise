# KMS Quick Reference

## 🚀 Quick Start

### Deploy KMS Keys

```bash
cd layers/security/environments/dev
terraform init -backend-config=backend.conf
terraform apply
```

### Get Key Information

```bash
# Key ID
terraform output kms_key_id

# Key ARN
terraform output kms_key_arn

# All key info
terraform output kms_keys_info
```

---

## 📋 Common Commands

### AWS CLI Commands

```bash
# Get AWS Account ID
aws sts get-caller-identity --query Account --output text

# List KMS keys
aws kms list-keys

# List aliases
aws kms list-aliases

# Describe key
aws kms describe-key --key-id <key-id>

# Get key policy
aws kms get-key-policy --key-id <key-id> --policy-name default

# Check rotation status
aws kms get-key-rotation-status --key-id <key-id>

# Enable rotation
aws kms enable-key-rotation --key-id <key-id>

# List grants
aws kms list-grants --key-id <key-id>

# Encrypt data
aws kms encrypt \
  --key-id <key-id> \
  --plaintext fileb://plaintext.txt \
  --output text \
  --query CiphertextBlob | base64 --decode > encrypted.bin

# Decrypt data
aws kms decrypt \
  --ciphertext-blob fileb://encrypted.bin \
  --output text \
  --query Plaintext | base64 --decode

# Generate data key
aws kms generate-data-key \
  --key-id <key-id> \
  --key-spec AES_256
```

### Terraform Commands

```bash
# Format code
terraform fmt -recursive

# Validate
terraform validate

# Plan
terraform plan

# Apply
terraform apply

# Destroy specific resource
terraform destroy -target=module.kms_rds

# Show state
terraform show

# List resources
terraform state list

# Get specific output
terraform output -raw kms_key_arn
```

---

## 🔑 Configuration Templates

### Development Environment

```hcl
# layers/security/environments/dev/terraform.tfvars

kms_deletion_window_in_days = 7
kms_enable_key_rotation     = true
kms_rotation_period_in_days = 365

create_rds_key = false
create_s3_key  = false
create_ebs_key = false
```

### Production Environment

```hcl
# layers/security/environments/prod/terraform.tfvars

kms_deletion_window_in_days = 30
kms_enable_key_rotation     = true
kms_rotation_period_in_days = 365

kms_key_administrators = [
  "arn:aws:iam::ACCOUNT_ID:role/SecurityAdmin"
]

kms_key_users = [
  "arn:aws:iam::ACCOUNT_ID:role/ApplicationRole"
]

create_rds_key = true
create_s3_key  = true
create_ebs_key = true
```

---

## 🎯 Key Specifications

### Symmetric Keys

| Spec | Usage | Algorithm |
|------|-------|-----------|
| SYMMETRIC_DEFAULT | ENCRYPT_DECRYPT | AES-256-GCM |

### Asymmetric RSA Keys

| Spec | Usage | Key Size |
|------|-------|----------|
| RSA_2048 | ENCRYPT_DECRYPT, SIGN_VERIFY | 2048-bit |
| RSA_3072 | ENCRYPT_DECRYPT, SIGN_VERIFY | 3072-bit |
| RSA_4096 | ENCRYPT_DECRYPT, SIGN_VERIFY | 4096-bit |

### Asymmetric ECC Keys

| Spec | Usage | Curve |
|------|-------|-------|
| ECC_NIST_P256 | SIGN_VERIFY | secp256r1 |
| ECC_NIST_P384 | SIGN_VERIFY | secp384r1 |
| ECC_NIST_P521 | SIGN_VERIFY | secp521r1 |

### HMAC Keys

| Spec | Usage | Output |
|------|-------|--------|
| HMAC_256 | GENERATE_VERIFY_MAC | 256 bits |
| HMAC_384 | GENERATE_VERIFY_MAC | 384 bits |
| HMAC_512 | GENERATE_VERIFY_MAC | 512 bits |

---

## 🔐 Service Integration

### S3 Bucket Encryption

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

### RDS Encryption

```hcl
resource "aws_db_instance" "example" {
  storage_encrypted = true
  kms_key_id        = module.kms_rds[0].key_arn
  # ... other config ...
}
```

### EBS Default Encryption

```bash
# Get EBS key ARN
EBS_KEY=$(terraform output -raw kms_ebs_key_arn)

# Set as default
aws ec2 modify-ebs-default-kms-key-id --kms-key-id $EBS_KEY

# Enable by default
aws ec2 enable-ebs-encryption-by-default
```

### CloudWatch Logs

```hcl
resource "aws_cloudwatch_log_group" "example" {
  name       = "/aws/app/logs"
  kms_key_id = module.kms_main.key_arn
}
```

### Lambda Environment Variables

```hcl
resource "aws_lambda_function" "example" {
  # ... other config ...
  kms_key_arn = module.kms_main.key_arn
  
  environment {
    variables = {
      SECRET = "encrypted_value"
    }
  }
}
```

---

## 🛡️ Security Checklist

### Before Deployment

- [ ] Update IAM ARNs in tfvars
- [ ] Set appropriate deletion window
- [ ] Enable key rotation
- [ ] Define service principals
- [ ] Configure ViaService conditions
- [ ] Review tags

### After Deployment

- [ ] Verify key creation
- [ ] Check rotation status
- [ ] Test encryption/decryption
- [ ] Configure service integrations
- [ ] Set up CloudWatch alarms
- [ ] Enable CloudTrail logging
- [ ] Document key purposes

### Monthly Maintenance

- [ ] Review key policies
- [ ] Audit key users
- [ ] Check rotation status
- [ ] Review CloudTrail logs
- [ ] Verify grants
- [ ] Update documentation

---

## 📊 Outputs Reference

### Security Layer Outputs

```bash
# Main KMS key
terraform output kms_key_id
terraform output kms_key_arn
terraform output kms_key_alias_name

# RDS key (if created)
terraform output kms_rds_key_id
terraform output kms_rds_key_arn

# S3 key (if created)
terraform output kms_s3_key_id
terraform output kms_s3_key_arn

# EBS key (if created)
terraform output kms_ebs_key_id
terraform output kms_ebs_key_arn

# Complete info
terraform output kms_keys_info
```

### Using Outputs in Other Layers

```hcl
# Reference from another layer
data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket = "terraform-state-${var.environment}-ACCOUNT_ID"
    key    = "layers/security/${var.environment}/terraform.tfstate"
    region = var.aws_region
  }
}

# Use the key
resource "aws_db_instance" "example" {
  kms_key_id = data.terraform_remote_state.security.outputs.kms_rds_key_arn
}
```

---

## 🚨 Troubleshooting

### Access Denied

```bash
# Check key policy
aws kms get-key-policy --key-id <key-id> --policy-name default

# Test permissions
aws kms encrypt \
  --key-id <key-id> \
  --plaintext "test" \
  --query CiphertextBlob
```

### Key Not Rotating

```bash
# Check status
aws kms get-key-rotation-status --key-id <key-id>

# Enable rotation
aws kms enable-key-rotation --key-id <key-id>

# Verify in Terraform
terraform plan  # Should show no changes if rotation is enabled
```

### Cannot Delete Key

```bash
# Schedule deletion
aws kms schedule-key-deletion \
  --key-id <key-id> \
  --pending-window-in-days 7

# Cancel deletion
aws kms cancel-key-deletion --key-id <key-id>

# Disable instead
aws kms disable-key --key-id <key-id>
```

### Terraform State Issues

```bash
# Backup state
terraform state pull > backup.tfstate

# List resources
terraform state list

# Show specific resource
terraform state show module.kms_main.aws_kms_key.this

# Import existing key
terraform import module.kms_main.aws_kms_key.this <key-id>
```

---

## 💡 Best Practices

### DO ✅

- Use separate keys for different services in production
- Enable key rotation
- Set appropriate deletion windows (30 days for prod)
- Use ViaService conditions
- Tag all keys
- Regular audits
- Monitor key usage
- Document key purposes

### DON'T ❌

- Share keys across environments
- Grant root access unless necessary
- Use overly broad permissions
- Disable rotation in production
- Delete keys immediately
- Skip tagging
- Ignore CloudTrail logs
- Use same key for everything

---

## 🔄 Common Workflows

### Enable Default EBS Encryption

```bash
# 1. Deploy EBS key
cd layers/security/environments/prod
terraform apply

# 2. Set as default
EBS_KEY=$(terraform output -raw kms_ebs_key_arn)
aws ec2 modify-ebs-default-kms-key-id --kms-key-id $EBS_KEY
aws ec2 enable-ebs-encryption-by-default

# 3. Verify
aws ec2 get-ebs-encryption-by-default
aws ec2 get-ebs-default-kms-key-id
```

### Rotate IAM Credentials

```bash
# 1. Get current key users
aws kms get-key-policy --key-id <key-id> --policy-name default

# 2. Update tfvars with new role ARN
# 3. Apply changes
terraform apply

# 4. Verify
aws kms get-key-policy --key-id <key-id> --policy-name default | jq '.Statement[]'
```

### Audit Key Usage

```bash
# CloudTrail events
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=<key-id> \
  --max-results 50 \
  --query 'Events[*].[EventTime,EventName,Username]' \
  --output table

# CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/KMS \
  --metric-name NumberOfDecryptCalls \
  --dimensions Name=KeyId,Value=<key-id> \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Sum
```

---

## 📚 Additional Resources

- [KMS Module README](modules/kms/README.md)
- [KMS Deployment Guide](KMS_DEPLOYMENT_GUIDE.md)
- [Security Layer README](layers/security/README.md)
- [AWS KMS Documentation](https://docs.aws.amazon.com/kms/)

---

## 🆘 Quick Help

```bash
# Get account ID
aws sts get-caller-identity --query Account --output text

# List all KMS keys
aws kms list-keys --output table

# Get key details
aws kms describe-key --key-id alias/mycompany/dev/main

# Test encryption
echo "test data" | aws kms encrypt \
  --key-id alias/mycompany/dev/main \
  --plaintext fileb:///dev/stdin \
  --query CiphertextBlob \
  --output text

# Terraform outputs
terraform output -json | jq '.'

# Validate config
terraform validate && terraform fmt -check -recursive
```

---

**Quick Reference v2.0** - For detailed information, see [KMS Deployment Guide](KMS_DEPLOYMENT_GUIDE.md)

