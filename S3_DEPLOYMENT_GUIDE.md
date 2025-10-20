# S3 Deployment Guide

## Overview

Complete guide for deploying and managing Amazon S3 buckets using the enterprise Terraform S3 module.

**Version:** 2.0 | **Status:** ✅ Production Ready

---

## Quick Start

### Deploy S3 Buckets

S3 buckets are automatically created in the storage layer:

```bash
cd layers/storage/environments/dev
terraform apply

# Outputs:
# - Application bucket
# - Logs bucket
```

### Configuration

Edit `terraform.tfvars`:

```hcl
# Encryption (production)
s3_enable_kms_encryption = true

# Lifecycle rules
s3_app_lifecycle_rules = [
  {
    id      = "archive"
    enabled = true
    transitions = [
      {
        days          = 30
        storage_class = "STANDARD_IA"
      }
    ]
  }
]
```

---

## Features

### Encryption

```hcl
# KMS encryption (recommended for production)
s3_enable_kms_encryption = true

# S3 Bucket Key (99% KMS cost reduction)
bucket_key_enabled = true
```

### Versioning

```hcl
s3_app_versioning_enabled = true

# Protect against accidental deletion
# Can recover previous versions
```

### Lifecycle Management

```hcl
lifecycle_rules = [
  {
    id      = "optimize-costs"
    enabled = true
    
    # Transition to cheaper storage
    transitions = [
      {
        days          = 30
        storage_class = "STANDARD_IA"  # 50% cheaper
      },
      {
        days          = 90
        storage_class = "GLACIER"      # 83% cheaper
      }
    ]
    
    # Delete old versions
    noncurrent_version_expiration = {
      noncurrent_days = 90
    }
  }
]
```

### Intelligent Tiering

```hcl
s3_app_intelligent_tiering = {
  entire_bucket = {
    tierings = [
      {
        access_tier = "ARCHIVE_ACCESS"
        days        = 90
      }
    ]
  }
}
```

Automatically moves objects between access tiers based on usage patterns.

### Cross-Region Replication

```hcl
s3_app_replication_enabled = true

s3_app_replication_rules = {
  dr = {
    destination_bucket = "arn:aws:s3:::backup-bucket"
    replica_kms_key_id = module.kms_west.key_arn
    replication_time_enabled = true
  }
}
```

---

## Security

- ✅ **Encryption at rest** - SSE-KMS or SSE-S3
- ✅ **Block public access** - Enabled by default
- ✅ **Enforce HTTPS** - Deny insecure transport
- ✅ **Versioning** - Protect against deletions
- ✅ **Access logging** - Audit trails
- ✅ **Bucket policies** - Fine-grained access control

---

## Cost Optimization

### Lifecycle Management (Automatic)

- After 30 days → STANDARD_IA (50% savings)
- After 90 days → GLACIER (83% savings)
- After 180 days → DEEP_ARCHIVE (95% savings)

### Intelligent Tiering (Recommended)

Automatically optimizes costs based on access patterns.

### S3 Bucket Key

Reduces KMS costs by 99%.

---

## Troubleshooting

### Access Denied

```bash
# Check bucket policy
aws s3api get-bucket-policy --bucket mybucket

# Check ACL
aws s3api get-bucket-acl --bucket mybucket
```

### Replication Not Working

```bash
# Check replication status
aws s3api get-bucket-replication --bucket mybucket

# Check IAM role
aws iam get-role --role-name replication-role
```

---

## References

- [S3 Module README](modules/s3/README.md)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)

---

**End of Guide**

