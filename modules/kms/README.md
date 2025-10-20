# KMS Module

## Description

Enterprise-grade AWS Key Management Service (KMS) module for creating and managing encryption keys with comprehensive policy controls, automatic rotation, and multi-region support.

## Features

- **Symmetric & Asymmetric Keys**: Support for ENCRYPT_DECRYPT, SIGN_VERIFY, and GENERATE_VERIFY_MAC
- **Automatic Key Rotation**: Configurable rotation periods (90-2560 days)
- **Comprehensive Key Policies**: Fine-grained access control with IAM principals and service principals
- **Key Aliases**: Human-readable key identifiers
- **Grants**: Temporary permissions for AWS services and resources
- **Multi-Region Keys**: Support for disaster recovery and global applications
- **CloudWatch Logs Integration**: Automatic permissions for log encryption
- **Service Integration**: Pre-configured permissions for AWS services
- **Compliance Ready**: FIPS 140-2 validated HSMs

## Resources Created

- `aws_kms_key` - Customer managed KMS key
- `aws_kms_alias` - Key alias for easier reference
- `aws_kms_grant` - Temporary key permissions
- `aws_iam_policy_document` - Comprehensive key policy

## Usage

### Basic Symmetric Encryption Key

```hcl
module "kms_basic" {
  source = "../../modules/kms"

  key_name    = "app-encryption-key"
  description = "Encryption key for application data"

  enable_key_rotation = true
  
  tags = {
    Environment = "production"
    Application = "web-app"
  }
}
```

### Production Key with Full Configuration

```hcl
module "kms_production" {
  source = "../../modules/kms"

  key_name    = "production-master-key"
  description = "Master encryption key for production environment"

  # Key configuration
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  deletion_window_in_days  = 30

  # Rotation
  enable_key_rotation     = true
  rotation_period_in_days = 365

  # Access control
  key_administrators = [
    "arn:aws:iam::123456789012:role/SecurityAdmin",
    "arn:aws:iam::123456789012:role/PlatformAdmin"
  ]

  key_users = [
    "arn:aws:iam::123456789012:role/ApplicationRole",
    "arn:aws:iam::123456789012:role/ECSTaskRole"
  ]

  # Service principals
  service_principals = [
    "logs.amazonaws.com",
    "s3.amazonaws.com",
    "rds.amazonaws.com"
  ]

  via_service_conditions = [
    "logs.us-east-1.amazonaws.com",
    "s3.us-east-1.amazonaws.com",
    "rds.us-east-1.amazonaws.com"
  ]

  # CloudWatch Logs
  enable_cloudwatch_logs = true

  # Grant permissions
  enable_grant_permissions = true

  # Alias
  create_alias = true
  alias_name   = "alias/production/master"

  tags = {
    Environment = "production"
    Purpose     = "master-encryption"
    Compliance  = "pci-dss"
  }
}
```

### Asymmetric Key for Digital Signatures

```hcl
module "kms_signing" {
  source = "../../modules/kms"

  key_name                 = "document-signing-key"
  description              = "Key for digitally signing documents"
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "RSA_4096"

  deletion_window_in_days = 30

  key_administrators = [
    "arn:aws:iam::123456789012:role/SecurityAdmin"
  ]

  key_users = [
    "arn:aws:iam::123456789012:role/DocumentProcessor"
  ]

  tags = {
    Purpose = "digital-signatures"
  }
}
```

### Multi-Region Key

```hcl
module "kms_multi_region" {
  source = "../../modules/kms"

  key_name     = "global-encryption-key"
  description  = "Multi-region key for global application"
  multi_region = true

  enable_key_rotation = true

  key_administrators = [
    "arn:aws:iam::123456789012:root"
  ]

  tags = {
    Type        = "multi-region"
    Application = "global-app"
  }
}
```

### Key with Grants

```hcl
module "kms_with_grants" {
  source = "../../modules/kms"

  key_name    = "s3-encryption-key"
  description = "Key for S3 bucket encryption"

  grants = {
    s3_grant = {
      grantee_principal = "arn:aws:iam::123456789012:role/S3Role"
      operations        = ["Encrypt", "Decrypt", "GenerateDataKey"]
      
      constraints = {
        encryption_context_equals = {
          "aws:s3:arn" = "arn:aws:s3:::my-bucket/*"
        }
      }
    }
    
    lambda_grant = {
      grantee_principal = "arn:aws:iam::123456789012:role/LambdaRole"
      operations        = ["Decrypt", "DescribeKey"]
    }
  }

  tags = {
    Service = "s3"
  }
}
```

## Inputs

### Required

| Name | Description | Type |
|------|-------------|------|
| key_name | Name of the KMS key | string |
| description | Description of the KMS key | string |

### Optional

| Name | Description | Type | Default |
|------|-------------|------|---------|
| key_usage | Intended use of the key | string | `"ENCRYPT_DECRYPT"` |
| customer_master_key_spec | Key material type | string | `"SYMMETRIC_DEFAULT"` |
| deletion_window_in_days | Deletion window (7-30 days) | number | `30` |
| enable_key_rotation | Enable automatic rotation | bool | `true` |
| rotation_period_in_days | Rotation period (90-2560 days) | number | `365` |
| multi_region | Multi-region key | bool | `false` |
| replica_regions | Replica regions map | map(any) | `{}` |
| policy | Custom key policy JSON | string | `null` |
| bypass_policy_lockout_safety_check | Bypass lockout check | bool | `false` |
| key_administrators | IAM ARNs for administrators | list(string) | `[]` |
| key_users | IAM ARNs for users | list(string) | `[]` |
| service_principals | AWS service principals | list(string) | `[]` |
| via_service_conditions | Services for ViaService condition | list(string) | `[]` |
| enable_cloudwatch_logs | Allow CloudWatch Logs | bool | `true` |
| enable_grant_permissions | Enable grant creation | bool | `true` |
| create_alias | Create key alias | bool | `true` |
| alias_name | Key alias name | string | `null` |
| grants | Map of grants to create | map(object) | `{}` |
| tags | Resource tags | map(string) | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| key_id | The globally unique identifier for the key |
| key_arn | The Amazon Resource Name (ARN) of the key |
| key_alias_name | The display name of the key alias |
| key_alias_arn | The ARN of the key alias |
| key_policy | The IAM resource policy (sensitive) |
| key_rotation_enabled | Whether key rotation is enabled |
| rotation_period_in_days | Rotation period in days |
| multi_region | Whether this is a multi-region key |
| grants | Map of grant IDs (sensitive) |
| grant_ids | List of grant IDs |
| key_spec | The type of key material |
| key_usage | The cryptographic operations |
| deletion_window_in_days | Deletion window duration |
| key_info | Complete key information object |

## Key Specifications

### Symmetric Keys

| Spec | Usage | Algorithms |
|------|-------|-----------|
| SYMMETRIC_DEFAULT | ENCRYPT_DECRYPT | AES-256-GCM |

### Asymmetric RSA Keys

| Spec | Usage | Algorithms |
|------|-------|-----------|
| RSA_2048 | ENCRYPT_DECRYPT, SIGN_VERIFY | RSA with 2048-bit key |
| RSA_3072 | ENCRYPT_DECRYPT, SIGN_VERIFY | RSA with 3072-bit key |
| RSA_4096 | ENCRYPT_DECRYPT, SIGN_VERIFY | RSA with 4096-bit key |

### Asymmetric ECC Keys

| Spec | Usage | Curve |
|------|-------|-------|
| ECC_NIST_P256 | SIGN_VERIFY | secp256r1 |
| ECC_NIST_P384 | SIGN_VERIFY | secp384r1 |
| ECC_NIST_P521 | SIGN_VERIFY | secp521r1 |
| ECC_SECG_P256K1 | SIGN_VERIFY | secp256k1 |

### HMAC Keys

| Spec | Usage | Output Length |
|------|-------|--------------|
| HMAC_224 | GENERATE_VERIFY_MAC | 224 bits |
| HMAC_256 | GENERATE_VERIFY_MAC | 256 bits |
| HMAC_384 | GENERATE_VERIFY_MAC | 384 bits |
| HMAC_512 | GENERATE_VERIFY_MAC | 512 bits |

## Key Policy

The module automatically generates a comprehensive key policy with the following statements:

### 1. Root Account Access
- Full control for the AWS account root user
- Enables IAM policies to grant access

### 2. Key Administrators
- Full administrative permissions
- Can manage key lifecycle, policies, and grants
- Cannot use the key for cryptographic operations

### 3. Key Users
- Cryptographic operation permissions based on key_usage:
  - **ENCRYPT_DECRYPT**: Encrypt, Decrypt, ReEncrypt, GenerateDataKey
  - **SIGN_VERIFY**: Sign, Verify
  - **GENERATE_VERIFY_MAC**: GenerateMac, VerifyMac

### 4. Service Principals
- Allows AWS services to use the key
- Includes ViaService condition for security
- Supports grant creation

### 5. CloudWatch Logs (if enabled)
- Allows CloudWatch Logs service to encrypt log groups
- Restricted by encryption context

### 6. Grant Permissions (if enabled)
- Allows key users to create grants
- Restricted to AWS resource grants only

## Best Practices

### Security

1. **Principle of Least Privilege**
   ```hcl
   key_users = [
     "arn:aws:iam::123456789012:role/ApplicationRole"
   ]
   # Don't add unnecessary users
   ```

2. **Separate Administrator and User Roles**
   ```hcl
   key_administrators = ["arn:aws:iam::123456789012:role/SecurityAdmin"]
   key_users          = ["arn:aws:iam::123456789012:role/AppRole"]
   ```

3. **Enable Key Rotation**
   ```hcl
   enable_key_rotation     = true
   rotation_period_in_days = 365  # Annual rotation
   ```

4. **Use Service Conditions**
   ```hcl
   service_principals = ["s3.amazonaws.com"]
   via_service_conditions = ["s3.us-east-1.amazonaws.com"]
   ```

### Operational

1. **Set Appropriate Deletion Windows**
   ```hcl
   # Development
   deletion_window_in_days = 7

   # Production
   deletion_window_in_days = 30
   ```

2. **Use Descriptive Aliases**
   ```hcl
   alias_name = "alias/production/app-name/purpose"
   ```

3. **Tag Your Keys**
   ```hcl
   tags = {
     Environment = "production"
     Application = "web-app"
     CostCenter  = "engineering"
     Compliance  = "pci-dss"
   }
   ```

4. **Monitor Key Usage**
   - Enable CloudTrail logging
   - Set up CloudWatch alarms for key operations
   - Review key policies regularly

### Cost Optimization

1. **Consolidate Keys When Appropriate**
   - One key per application/environment
   - Don't create unnecessary keys

2. **Delete Unused Keys**
   ```bash
   # List keys
   aws kms list-keys
   
   # Check key usage
   aws kms get-key-rotation-status --key-id <key-id>
   ```

3. **Use Grants for Temporary Access**
   - More cost-effective than creating new keys
   - Can be revoked easily

## Multi-Region Keys

Multi-region keys provide disaster recovery and data sovereignty capabilities:

### Primary Key

```hcl
module "primary_key" {
  source = "../../modules/kms"

  key_name     = "global-app-key"
  description  = "Multi-region key - Primary in us-east-1"
  multi_region = true

  enable_key_rotation = true

  tags = {
    Region = "us-east-1"
    Type   = "primary"
  }
}
```

### Replica Key (Separate Deployment)

```hcl
# Deploy in us-west-2 region
provider "aws" {
  region = "us-west-2"
}

resource "aws_kms_replica_key" "replica" {
  description             = "Global app key replica in us-west-2"
  primary_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/mrk-xxxxx"
  deletion_window_in_days = 30

  tags = {
    Region = "us-west-2"
    Type   = "replica"
  }
}
```

## Grants

Grants provide temporary, revocable permissions:

```hcl
grants = {
  ec2_autoscaling = {
    grantee_principal = "arn:aws:iam::123456789012:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
    operations        = ["Encrypt", "Decrypt", "GenerateDataKey", "CreateGrant", "RetireGrant"]
    
    constraints = {
      encryption_context_subset = {
        "aws:autoscaling:groupName" = "my-asg"
      }
    }
  }
}
```

## Integration Examples

### S3 Bucket Encryption

```hcl
module "s3_key" {
  source = "../../modules/kms"

  key_name    = "s3-bucket-encryption"
  description = "Key for S3 bucket encryption"

  service_principals = ["s3.amazonaws.com"]
  via_service_conditions = ["s3.${var.region}.amazonaws.com"]

  tags = {
    Service = "s3"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket" {
  bucket = aws_s3_bucket.example.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = module.s3_key.key_arn
    }
  }
}
```

### RDS Encryption

```hcl
module "rds_key" {
  source = "../../modules/kms"

  key_name    = "rds-encryption"
  description = "Key for RDS database encryption"

  service_principals = ["rds.amazonaws.com"]
  via_service_conditions = ["rds.${var.region}.amazonaws.com"]

  enable_grant_permissions = true

  tags = {
    Service = "rds"
  }
}

resource "aws_db_instance" "example" {
  # ... other configuration ...
  
  storage_encrypted = true
  kms_key_id        = module.rds_key.key_arn
}
```

### EBS Encryption

```hcl
module "ebs_key" {
  source = "../../modules/kms"

  key_name    = "ebs-encryption"
  description = "Default key for EBS volume encryption"

  service_principals = ["ec2.amazonaws.com"]
  via_service_conditions = ["ec2.${var.region}.amazonaws.com"]

  enable_grant_permissions = true

  tags = {
    Service = "ebs"
  }
}

resource "aws_ebs_default_kms_key" "default" {
  key_arn = module.ebs_key.key_arn
}

resource "aws_ebs_encryption_by_default" "enabled" {
  enabled = true
}
```

### CloudWatch Logs

```hcl
module "logs_key" {
  source = "../../modules/kms"

  key_name    = "cloudwatch-logs-encryption"
  description = "Key for CloudWatch Logs encryption"

  enable_cloudwatch_logs = true

  tags = {
    Service = "cloudwatch-logs"
  }
}

resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/application/logs"
  kms_key_id        = module.logs_key.key_arn
  retention_in_days = 30
}
```

## Troubleshooting

### Key Policy Lockout

If you accidentally lock yourself out:

```bash
# Use root account credentials
aws kms put-key-policy \
  --key-id <key-id> \
  --policy-name default \
  --policy file://emergency-policy.json
```

### Rotation Issues

```bash
# Check rotation status
aws kms get-key-rotation-status --key-id <key-id>

# Enable rotation
aws kms enable-key-rotation --key-id <key-id>
```

### Access Denied Errors

1. Check key policy includes your principal
2. Verify IAM policies allow KMS operations
3. Check ViaService conditions if using service principals
4. Review grants for the key

```bash
# List grants
aws kms list-grants --key-id <key-id>

# Describe key
aws kms describe-key --key-id <key-id>
```

## Compliance & Security

### FIPS 140-2 Compliance

All KMS keys use FIPS 140-2 validated Hardware Security Modules (HSMs).

### Audit & Monitoring

```hcl
# CloudTrail automatically logs all KMS API calls
# Set up CloudWatch alarms:

resource "aws_cloudwatch_metric_alarm" "kms_deletions" {
  alarm_name          = "kms-key-deletions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UserErrorCount"
  namespace           = "AWS/KMS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert on KMS key deletion attempts"
  
  dimensions = {
    KeyId = module.kms.key_id
  }
}
```

## References

- [AWS KMS Developer Guide](https://docs.aws.amazon.com/kms/latest/developerguide/)
- [KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [KMS Pricing](https://aws.amazon.com/kms/pricing/)
- [FIPS 140-2 Compliance](https://aws.amazon.com/compliance/fips/)

## Related Modules

- [IAM Module](../iam/README.md)
- [S3 Module](../s3/README.md)
- [RDS Module](../rds/README.md)
