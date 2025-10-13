# ECR (Elastic Container Registry) Module

## Overview

This Terraform module creates and manages AWS Elastic Container Registry (ECR) repositories with comprehensive security features, lifecycle management, and scanning capabilities.

## Features

### 🔐 Security
- **Encryption at rest** with AES256 or KMS
- **Image scanning** on push with basic or enhanced scanning
- **Repository policies** for access control
- **Cross-account access** support
- **Lambda integration** for container-based Lambda functions
- **IAM-based authentication**

### 🔄 Lifecycle Management
- **Automatic image cleanup** based on count or age
- **Customizable lifecycle policies**
- **Tag-based retention rules**

### 📊 Scanning & Monitoring
- **Scan on push** for immediate vulnerability detection
- **Enhanced scanning** with continuous monitoring
- **CloudWatch integration** for scan findings
- **Configurable scan frequency**

### 🌍 Replication
- **Multi-region replication** for disaster recovery
- **Cross-account replication** support
- **Selective replication** with filters

### 🚀 Performance
- **Pull through cache** for public registries (Docker Hub, ECR Public)
- **Optimized image layers**
- **Fast pull/push operations**

## Usage

### Basic Example

```hcl
module "ecr" {
  source = "../../modules/ecr"

  repository_name      = "my-application"
  image_tag_mutability = "IMMUTABLE"
  scan_on_push         = true

  tags = {
    Environment = "production"
    Application = "web-app"
  }
}
```

### Advanced Example with KMS Encryption

```hcl
module "ecr_encrypted" {
  source = "../../modules/ecr"

  repository_name = "secure-application"
  
  # Encryption
  encryption_type = "KMS"
  kms_key_arn     = aws_kms_key.ecr.arn
  
  # Scanning
  scan_on_push            = true
  enable_enhanced_scanning = true
  scan_frequency          = "CONTINUOUS_SCAN"
  
  # Lifecycle
  max_image_count = 50
  
  # Immutable tags for production
  image_tag_mutability = "IMMUTABLE"
  
  tags = {
    Environment = "production"
    Compliance  = "required"
  }
}
```

### Cross-Account Access

```hcl
module "ecr_shared" {
  source = "../../modules/ecr"

  repository_name = "shared-images"
  
  # Enable cross-account access
  enable_cross_account_access = true
  allowed_account_ids = [
    "123456789012",  # Development account
    "210987654321"   # Staging account
  ]
  
  tags = {
    Shared = "true"
  }
}
```

### Multi-Region Replication

```hcl
module "ecr_replicated" {
  source = "../../modules/ecr"

  repository_name = "disaster-recovery-app"
  
  # Enable replication
  enable_replication = true
  replication_destinations = [
    {
      region      = "us-west-2"
      registry_id = data.aws_caller_identity.current.account_id
    },
    {
      region      = "eu-west-1"
      registry_id = data.aws_caller_identity.current.account_id
    }
  ]
  
  tags = {
    DR = "enabled"
  }
}
```

### Lambda Container Support

```hcl
module "ecr_lambda" {
  source = "../../modules/ecr"

  repository_name = "lambda-function"
  
  # Enable Lambda service to pull images
  enable_lambda_pull = true
  
  # Enhanced scanning for security
  scan_on_push            = true
  enable_enhanced_scanning = true
  
  tags = {
    Type = "lambda-container"
  }
}
```

### Pull Through Cache (Docker Hub)

```hcl
module "ecr_cache" {
  source = "../../modules/ecr"

  repository_name = "cached-images"
  
  # Enable pull through cache
  enable_pull_through_cache       = true
  pull_through_cache_prefix       = "docker-hub"
  upstream_registry_url           = "registry-1.docker.io"
  pull_through_cache_credential_arn = aws_secretsmanager_secret.dockerhub.arn
  
  tags = {
    Cache = "docker-hub"
  }
}
```

### Custom Lifecycle Policy

```hcl
module "ecr_custom_lifecycle" {
  source = "../../modules/ecr"

  repository_name = "production-app"
  
  lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prod"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
  
  tags = {
    Lifecycle = "custom"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Resources Created

This module creates the following resources:

- `aws_ecr_repository` - ECR repository
- `aws_ecr_lifecycle_policy` - Lifecycle policy (optional)
- `aws_ecr_repository_policy` - Repository policy (optional)
- `aws_ecr_replication_configuration` - Replication config (optional)
- `aws_ecr_registry_scanning_configuration` - Enhanced scanning (optional)
- `aws_ecr_pull_through_cache_rule` - Pull through cache (optional)
- `aws_ecr_registry_policy` - Registry policy (optional)
- `aws_cloudwatch_log_group` - Scan findings logs (optional)

## Inputs

### Required Inputs

| Name | Description | Type |
|------|-------------|------|
| repository_name | Name of the ECR repository | `string` |

### Optional Inputs

#### Basic Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| image_tag_mutability | Tag mutability (MUTABLE or IMMUTABLE) | `string` | `"MUTABLE"` |
| force_delete | Delete repository even with images | `bool` | `false` |
| tags | Map of tags to add to resources | `map(string)` | `{}` |

#### Encryption

| Name | Description | Type | Default |
|------|-------------|------|---------|
| encryption_type | Encryption type (AES256 or KMS) | `string` | `"AES256"` |
| kms_key_arn | KMS key ARN (required if encryption_type is KMS) | `string` | `null` |

#### Scanning

| Name | Description | Type | Default |
|------|-------------|------|---------|
| scan_on_push | Scan images on push | `bool` | `true` |
| enable_enhanced_scanning | Enable continuous vulnerability scanning | `bool` | `false` |
| scan_frequency | Scan frequency (SCAN_ON_PUSH, CONTINUOUS_SCAN, MANUAL) | `string` | `"SCAN_ON_PUSH"` |
| enable_scan_findings_logging | Enable CloudWatch logging for scan findings | `bool` | `false` |
| log_retention_days | Retention days for scan findings logs | `number` | `30` |

#### Lifecycle Policy

| Name | Description | Type | Default |
|------|-------------|------|---------|
| lifecycle_policy | Custom lifecycle policy JSON | `string` | `null` |
| max_image_count | Max images to keep (default policy) | `number` | `100` |

#### Repository Policy

| Name | Description | Type | Default |
|------|-------------|------|---------|
| repository_policy | Custom repository policy JSON | `string` | `null` |
| enable_cross_account_access | Enable cross-account access | `bool` | `false` |
| allowed_account_ids | AWS account IDs allowed to pull | `list(string)` | `[]` |
| enable_lambda_pull | Enable Lambda to pull images | `bool` | `false` |

#### Replication

| Name | Description | Type | Default |
|------|-------------|------|---------|
| enable_replication | Enable ECR replication | `bool` | `false` |
| replication_destinations | List of replication destinations | `list(object)` | `[]` |

#### Pull Through Cache

| Name | Description | Type | Default |
|------|-------------|------|---------|
| enable_pull_through_cache | Enable pull through cache | `bool` | `false` |
| pull_through_cache_prefix | Repository prefix for cache | `string` | `"ecr-public"` |
| upstream_registry_url | Upstream registry URL | `string` | `"public.ecr.aws"` |
| pull_through_cache_credential_arn | Credentials secret ARN | `string` | `null` |

## Outputs

| Name | Description |
|------|-------------|
| repository_arn | Full ARN of the ECR repository |
| repository_url | URL for docker push/pull operations |
| repository_name | Name of the ECR repository |
| repository_registry_id | Registry ID where repository was created |
| repository_id | ID of the repository |
| scan_on_push_enabled | Whether scan on push is enabled |
| enhanced_scanning_enabled | Whether enhanced scanning is enabled |
| scan_findings_log_group | CloudWatch log group for scan findings |
| encryption_type | Encryption type used |
| kms_key_arn | KMS key ARN (if KMS encryption enabled) |
| lifecycle_policy_enabled | Whether lifecycle policy is enabled |
| cross_account_access_enabled | Whether cross-account access is enabled |
| lambda_pull_enabled | Whether Lambda pull is enabled |
| replication_enabled | Whether replication is enabled |
| replication_destinations | List of replication destinations |
| image_tag_mutability | Tag mutability setting |
| pull_through_cache_enabled | Whether pull through cache is enabled |

## Docker Commands

### Authentication

```bash
# Get login password and authenticate
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  $(terraform output -raw repository_url | cut -d'/' -f1)
```

### Build and Push

```bash
# Build image
docker build -t my-app:latest .

# Tag image
docker tag my-app:latest $(terraform output -raw repository_url):latest

# Push image
docker push $(terraform output -raw repository_url):latest
```

### Pull Image

```bash
# Pull specific tag
docker pull $(terraform output -raw repository_url):v1.0.0

# Pull latest
docker pull $(terraform output -raw repository_url):latest
```

## Security Best Practices

### 1. Use KMS Encryption for Sensitive Images
```hcl
encryption_type = "KMS"
kms_key_arn     = aws_kms_key.ecr.arn
```

### 2. Enable Immutable Tags for Production
```hcl
image_tag_mutability = "IMMUTABLE"
```

### 3. Always Enable Scanning
```hcl
scan_on_push            = true
enable_enhanced_scanning = true
scan_frequency          = "CONTINUOUS_SCAN"
```

### 4. Implement Lifecycle Policies
```hcl
max_image_count = 50  # Prevent unlimited storage costs
```

### 5. Use Cross-Account Access Instead of Public
```hcl
enable_cross_account_access = true
allowed_account_ids = ["123456789012"]
```

### 6. Enable Scan Findings Logging
```hcl
enable_scan_findings_logging = true
log_retention_days          = 90
```

## Cost Optimization

1. **Lifecycle Policies**: Automatically delete old images
2. **Image Compression**: Use multi-stage builds and alpine base images
3. **Replication**: Only replicate to necessary regions
4. **Enhanced Scanning**: Enable only for critical repositories

## Monitoring

### CloudWatch Metrics

The module automatically creates CloudWatch metrics for:
- Repository storage usage
- Image push/pull counts
- Scan findings

### Alarms (Configure Separately)

```hcl
resource "aws_cloudwatch_metric_alarm" "high_severity_findings" {
  alarm_name          = "${module.ecr.repository_name}-high-severity"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HighSeverityFindings"
  namespace           = "AWS/ECR"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert on high severity vulnerabilities"
  
  dimensions = {
    RepositoryName = module.ecr.repository_name
  }
}
```

## Troubleshooting

### Issue: Unable to push images
**Solution**: Check IAM permissions and ensure you're authenticated:
```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com
```

### Issue: Lifecycle policy not deleting images
**Solution**: Verify the policy syntax and ensure the count/age thresholds are correct.

### Issue: Cross-account access not working
**Solution**: Check that:
1. Repository policy includes the target account ID
2. Target account has proper IAM permissions
3. Both accounts are in the same partition (aws, aws-cn, aws-us-gov)

### Issue: Enhanced scanning not enabled
**Solution**: Enhanced scanning requires:
- AWS Organization with specific features enabled
- Proper service-linked role
- Account-level configuration

## Examples

See the `examples/` directory for complete working examples:
- Basic ECR repository
- Production-ready with all features
- Multi-account setup
- Lambda container images
- CI/CD integration

## Contributing

When contributing to this module:
1. Follow Terraform best practices
2. Update documentation
3. Add examples for new features
4. Test with `terraform validate` and `terraform plan`

## License

This module is part of the Enterprise AWS Infrastructure project.

## Authors

Maintained by the Platform Engineering Team

## References

- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [ECR Best Practices](https://docs.aws.amazon.com/AmazonECR/latest/userguide/best-practices.html)
- [Container Image Scanning](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning.html)
