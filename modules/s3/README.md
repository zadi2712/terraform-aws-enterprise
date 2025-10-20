# S3 Module

## Description

Enterprise-grade Amazon S3 module for object storage with encryption, versioning, lifecycle management, replication, and comprehensive security controls.

## Features

- **Encryption**: SSE-S3 or SSE-KMS with S3 Bucket Key
- **Versioning**: Object versioning with MFA delete
- **Lifecycle Management**: Automated transitions and expiration
- **Intelligent Tiering**: Automatic cost optimization
- **Replication**: Cross-region and same-region
- **Public Access Block**: Prevent accidental public exposure
- **Bucket Policies**: Custom access control
- **CORS**: Cross-origin resource sharing
- **Logging**: Access logging
- **Notifications**: Lambda, SQS, SNS triggers
- **Website Hosting**: Static website support
- **Object Lock**: WORM compliance
- **Analytics & Inventory**: Usage insights

## Usage

### Basic Bucket

```hcl
module "app_bucket" {
  source = "../../modules/s3"

  bucket_name       = "myapp-prod-data"
  versioning_enabled = true
  kms_key_id        = module.kms_s3.key_arn

  lifecycle_rules = [{
    id      = "archive-old-data"
    enabled = true
    
    transitions = [
      {
        days          = 90
        storage_class = "GLACIER"
      }
    ]
  }]

  tags = {
    Purpose = "application-data"
  }
}
```

### Production Bucket with Full Features

```hcl
module "prod_bucket" {
  source = "../../modules/s3"

  bucket_name       = "myapp-prod-${data.aws_caller_identity.current.account_id}"
  versioning_enabled = true
  kms_key_id        = module.kms_s3.key_arn
  bucket_key_enabled = true

  # Block all public access
  block_public_access = true

  # Enforce HTTPS
  attach_deny_insecure_transport_policy = true

  # Lifecycle management
  lifecycle_rules = [
    {
      id      = "transition-to-ia"
      enabled = true
      
      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER_IR"
        },
        {
          days          = 180
          storage_class = "GLACIER"
        }
      ]
      
      noncurrent_version_transitions = [
        {
          noncurrent_days = 30
          storage_class   = "STANDARD_IA"
        }
      ]
      
      noncurrent_version_expiration = {
        noncurrent_days = 90
      }
    }
  ]

  # Intelligent Tiering
  intelligent_tiering_configurations = {
    entire_bucket = {
      tierings = [
        {
          access_tier = "ARCHIVE_ACCESS"
          days        = 90
        },
        {
          access_tier = "DEEP_ARCHIVE_ACCESS"
          days        = 180
        }
      ]
    }
  }

  # Cross-region replication
  replication_enabled = true
  
  replication_rules = {
    dr_replica = {
      destination_bucket       = "arn:aws:s3:::myapp-prod-dr-backup"
      replica_kms_key_id       = module.kms_west.key_arn
      replication_time_enabled = true
      delete_marker_replication = true
    }
  }

  # Access logging
  logging_enabled       = true
  logging_target_bucket = "myapp-logs"
  logging_target_prefix = "s3-access/"

  # Event notifications
  enable_notifications = true
  
  lambda_notifications = {
    process_uploads = {
      function_arn  = module.processor_lambda.function_arn
      events        = ["s3:ObjectCreated:*"]
      filter_suffix = ".csv"
    }
  }

  tags = {
    Environment = "production"
    Critical    = "true"
    Backup      = "required"
  }
}
```

## Best Practices

1. ✅ **Always encrypt** - Use SSE-KMS with dedicated key
2. ✅ **Enable versioning** - Protect against deletions
3. ✅ **Block public access** - Prevent data leaks
4. ✅ **Use lifecycle policies** - Reduce storage costs
5. ✅ **Enable replication** - Disaster recovery
6. ✅ **Enable logging** - Audit access
7. ✅ **Use Bucket Keys** - Reduce KMS costs by 99%
8. ✅ **Enforce HTTPS** - Secure transport
9. ✅ **Enable Intelligent Tiering** - Auto cost optimization
10. ✅ **Tag buckets** - Cost allocation

## Storage Classes

| Class | Retrieval | Price/GB | Use Case |
|-------|-----------|----------|----------|
| STANDARD | Immediate | $0.023 | Frequently accessed |
| STANDARD_IA | Immediate | $0.0125 | Infrequent access |
| INTELLIGENT_TIERING | Immediate | $0.023-$0.0125 | Unknown patterns |
| GLACIER_IR | Minutes | $0.004 | Archive, instant retrieval |
| GLACIER | Hours | $0.004 | Long-term archive |
| DEEP_ARCHIVE | 12 hours | $0.00099 | Compliance archives |

## References

- [S3 User Guide](https://docs.aws.amazon.com/s3/)
- [S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [S3 Pricing](https://aws.amazon.com/s3/pricing/)
