# ECR Integration Guide

## 📋 Overview

This guide explains how to use the ECR (Elastic Container Registry) module integrated into the compute layer of your infrastructure.

## 🎯 What is ECR?

Amazon Elastic Container Registry (ECR) is a fully managed container registry that makes it easy to store, manage, share, and deploy container images. It's integrated with:
- **Amazon ECS** (Elastic Container Service)
- **Amazon EKS** (Elastic Kubernetes Service)  
- **AWS Lambda** (for container-based functions)
- **Docker CLI** (standard docker push/pull)

## 🏗️ Architecture

### Integration Points

```
┌─────────────────────────────────────────────────────────┐
│                    Compute Layer                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │              ECR Repositories                     │  │
│  │  ├─ web-app                                       │  │
│  │  ├─ api-service                                   │  │
│  │  ├─ worker                                        │  │
│  │  └─ lambda-processor                              │  │
│  └──────────────────────────────────────────────────┘  │
│                       │                                  │
│                       ├──────────┬──────────┐           │
│                       │          │          │           │
│              ┌────────▼───┐ ┌───▼────┐ ┌──▼──────┐     │
│              │    EKS     │ │  ECS   │ │ Lambda  │     │
│              │  Cluster   │ │Cluster │ │Functions│     │
│              └────────────┘ └────────┘ └─────────┘     │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Security Integration

```
┌────────────────────┐
│   Security Layer   │
│                    │
│  ├─ KMS Keys       ├─────┐
│  ├─ IAM Roles      │     │
│  └─ Secrets        │     │
└────────────────────┘     │
                           │
                           ▼
                  ┌─────────────────┐
                  │  ECR + KMS      │
                  │  Encryption     │
                  └─────────────────┘
```

## 🚀 Quick Start

### Step 1: Define Your Repositories

Edit `layers/compute/environments/dev/terraform.tfvars`:

```hcl
ecr_repositories = {
  "web-app" = {
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    max_image_count      = 50
  }
  
  "api-service" = {
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    max_image_count      = 30
  }
}

ecr_encryption_type = "AES256"
```

### Step 2: Deploy

```bash
# Deploy compute layer with ECR repositories
cd layers/compute/environments/dev
terraform init
terraform plan
terraform apply
```

### Step 3: Get Repository URLs

```bash
# Get all repository URLs
terraform output ecr_repository_urls

# Output example:
# {
#   "api-service" = "123456789012.dkr.ecr.us-east-1.amazonaws.com/myproject-dev-api-service"
#   "web-app" = "123456789012.dkr.ecr.us-east-1.amazonaws.com/myproject-dev-web-app"
# }
```

### Step 4: Push Your First Image

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com

# Build your image
docker build -t web-app:latest .

# Tag for ECR
docker tag web-app:latest \
  123456789012.dkr.ecr.us-east-1.amazonaws.com/myproject-dev-web-app:latest

# Push to ECR
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/myproject-dev-web-app:latest
```

## 📊 Configuration Options

### Repository Configuration

Each repository in `ecr_repositories` map supports these options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `image_tag_mutability` | string | `"MUTABLE"` | MUTABLE or IMMUTABLE tags |
| `scan_on_push` | bool | `true` | Scan images when pushed |
| `enable_enhanced_scanning` | bool | `false` | Continuous vulnerability scanning |
| `scan_frequency` | string | `"SCAN_ON_PUSH"` | SCAN_ON_PUSH, CONTINUOUS_SCAN, MANUAL |
| `max_image_count` | number | `100` | Max images to keep |
| `lifecycle_policy` | string | `null` | Custom lifecycle policy JSON |
| `enable_cross_account_access` | bool | `false` | Allow other accounts to pull |
| `allowed_account_ids` | list(string) | `[]` | Account IDs with pull access |
| `enable_lambda_pull` | bool | `false` | Allow Lambda to pull images |
| `enable_replication` | bool | `false` | Enable multi-region replication |
| `replication_destinations` | list(object) | `[]` | Replication target regions |

### Layer-Level Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `ecr_encryption_type` | string | `"AES256"` | AES256 or KMS |
| `ecr_enable_scan_findings_logging` | bool | `false` | Log scan results to CloudWatch |
| `ecr_log_retention_days` | number | `30` | Days to retain scan logs |

## 🌍 Environment-Specific Configurations

### Development Environment

```hcl
ecr_repositories = {
  "web-app" = {
    image_tag_mutability     = "MUTABLE"      # Allow tag updates
    scan_on_push             = true
    enable_enhanced_scanning = false          # Basic scanning
    max_image_count          = 50             # Less retention
    enable_cross_account_access = false       # Isolated
  }
}

ecr_encryption_type = "AES256"                # Standard encryption
ecr_enable_scan_findings_logging = false      # Save costs
```

### Production Environment

```hcl
ecr_repositories = {
  "web-app" = {
    image_tag_mutability     = "IMMUTABLE"    # Prevent tag changes
    scan_on_push             = true
    enable_enhanced_scanning = true           # Continuous scanning
    scan_frequency           = "CONTINUOUS_SCAN"
    max_image_count          = 100            # More retention
    enable_cross_account_access = true        # Share with UAT/QA
    allowed_account_ids      = ["123456789012", "210987654321"]
    enable_replication       = true           # DR strategy
    replication_destinations = [
      {
        region      = "us-west-2"
        registry_id = "YOUR_ACCOUNT_ID"
      }
    ]
  }
}

ecr_encryption_type = "KMS"                   # Enhanced encryption
ecr_enable_scan_findings_logging = true       # Compliance logging
ecr_log_retention_days = 90                   # Longer retention
```

## 🔐 Security Best Practices

### 1. Encryption

**Development:**
```hcl
ecr_encryption_type = "AES256"  # Standard encryption
```

**Production:**
```hcl
ecr_encryption_type = "KMS"     # Customer-managed keys
# Uses KMS key from security layer automatically
```

### 2. Image Tag Mutability

**Development:**
```hcl
image_tag_mutability = "MUTABLE"  # Allow tag updates for testing
```

**Production:**
```hcl
image_tag_mutability = "IMMUTABLE"  # Prevent accidental overwrites
```

### 3. Image Scanning

**Minimum (All Environments):**
```hcl
scan_on_push = true  # Scan every image
```

**Enhanced (Production):**
```hcl
scan_on_push             = true
enable_enhanced_scanning = true
scan_frequency           = "CONTINUOUS_SCAN"  # Continuous monitoring
```

### 4. Cross-Account Access

Only enable when necessary:

```hcl
enable_cross_account_access = true
allowed_account_ids = [
  "123456789012"  # Only specific accounts
]
```

### 5. Lifecycle Policies

Prevent unlimited storage costs:

```hcl
# Simple: Keep last N images
max_image_count = 50

# Or custom policy:
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
    }
  ]
})
```

## 🔄 CI/CD Integration

### GitHub Actions

```yaml
name: Build and Push to ECR

on:
  push:
    branches: [main, dev]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Login to ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Build, tag, and push image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: myproject-dev-web-app
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG \
                     $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
```

### GitLab CI

```yaml
build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - apk add --no-cache python3 py3-pip
    - pip3 install awscli
    - aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY
  script:
    - docker build -t $ECR_REGISTRY/myproject-dev-web-app:$CI_COMMIT_SHA .
    - docker push $ECR_REGISTRY/myproject-dev-web-app:$CI_COMMIT_SHA
```

## 📱 Using ECR with Container Services

### EKS (Kubernetes)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: web-app
        image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/myproject-prod-web-app:v1.2.3
        ports:
        - containerPort: 8080
```

### ECS (Fargate)

```hcl
resource "aws_ecs_task_definition" "app" {
  family = "web-app"
  container_definitions = jsonencode([
    {
      name  = "web-app"
      image = "${module.ecr_repositories["web-app"].repository_url}:latest"
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
    }
  ])
}
```

### Lambda Container

```hcl
resource "aws_lambda_function" "processor" {
  function_name = "image-processor"
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = "${module.ecr_repositories["lambda-processor"].repository_url}:latest"
  
  environment {
    variables = {
      ENV = "production"
    }
  }
}
```

## 🔍 Monitoring and Operations

### View Scan Results

```bash
# List images in repository
aws ecr list-images \
  --repository-name myproject-dev-web-app \
  --region us-east-1

# Get scan findings for specific image
aws ecr describe-image-scan-findings \
  --repository-name myproject-dev-web-app \
  --image-id imageTag=latest \
  --region us-east-1
```

### Check Repository Details

```bash
# Describe repository
aws ecr describe-repositories \
  --repository-names myproject-dev-web-app \
  --region us-east-1

# Get lifecycle policy
aws ecr get-lifecycle-policy \
  --repository-name myproject-dev-web-app \
  --region us-east-1
```

### CloudWatch Metrics

ECR automatically provides these metrics:
- `RepositoryPullCount` - Number of pulls
- `RepositoryPushCount` - Number of pushes
- Storage used per repository

```bash
# View metrics via AWS CLI
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECR \
  --metric-name RepositoryPullCount \
  --dimensions Name=RepositoryName,Value=myproject-dev-web-app \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

## 💰 Cost Optimization

### 1. Lifecycle Policies

Remove old images automatically:
```hcl
max_image_count = 50  # Keep only last 50 images
```

### 2. Replication

Only replicate critical repositories:
```hcl
# Don't replicate dev/test repositories
enable_replication = var.environment == "prod"
```

### 3. Enhanced Scanning

Enable selectively:
```hcl
# Only for production and critical services
enable_enhanced_scanning = contains(["prod", "uat"], var.environment)
```

### 4. Image Compression

Use multi-stage builds:
```dockerfile
# Build stage
FROM node:18 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage
FROM node:18-alpine  # Smaller base image
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
CMD ["node", "dist/main.js"]
```

## 🚨 Troubleshooting

### Issue: Cannot authenticate to ECR

**Error:**
```
Error saving credentials: error storing credentials
```

**Solution:**
```bash
# Clear Docker credentials
rm ~/.docker/config.json

# Re-authenticate
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com
```

### Issue: Permission denied when pushing

**Error:**
```
denied: Your authorization token has expired
```

**Solution:**
```bash
# Get fresh authentication token
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com
```

### Issue: Image vulnerabilities found

**Solution:**
1. Review scan findings:
```bash
aws ecr describe-image-scan-findings \
  --repository-name myproject-dev-web-app \
  --image-id imageTag=latest
```

2. Update base image and dependencies
3. Rebuild and push new image
4. Re-scan

### Issue: Lifecycle policy not deleting images

**Check:**
1. Verify policy syntax
2. Check if images match selection criteria
3. Wait 24 hours (policies run daily)

```bash
# Verify policy
aws ecr get-lifecycle-policy \
  --repository-name myproject-dev-web-app
```

## 📚 Additional Resources

### Module Documentation
- [ECR Module README](../modules/ecr/README.md)
- [ECR Module Variables](../modules/ecr/variables.tf)
- [ECR Module Outputs](../modules/ecr/outputs.tf)

### Configuration Examples
- [Development Example](../layers/compute/environments/ecr-examples-dev.tfvars)
- [Production Example](../layers/compute/environments/ecr-examples-prod.tfvars)

### AWS Documentation
- [ECR User Guide](https://docs.aws.amazon.com/ecr/)
- [ECR Best Practices](https://docs.aws.amazon.com/AmazonECR/latest/userguide/best-practices.html)
- [Image Scanning](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning.html)
- [Lifecycle Policies](https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html)

### Docker Documentation
- [Docker Build](https://docs.docker.com/engine/reference/commandline/build/)
- [Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Best Practices](https://docs.docker.com/develop/dev-best-practices/)

## 🤝 Contributing

When adding new ECR repositories:
1. Add to `ecr_repositories` map in tfvars
2. Document the purpose and configuration
3. Set appropriate lifecycle policies
4. Enable scanning
5. Test push/pull operations

## 📞 Support

For ECR-related issues:
- Check this guide first
- Review [module documentation](../modules/ecr/README.md)
- Check [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- Contact Platform Engineering team

---

**Last Updated:** October 2025  
**Maintained By:** Platform Engineering Team
