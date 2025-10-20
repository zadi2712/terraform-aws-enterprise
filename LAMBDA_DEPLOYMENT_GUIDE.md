# Lambda Deployment Guide

## Overview

Complete guide for deploying and managing AWS Lambda serverless functions using the enterprise Terraform Lambda module.

**Version:** 2.0  
**Last Updated:** October 20, 2025  
**Status:** ✅ Production Ready

---

## Table of Contents

1. [What is Lambda](#what-is-lambda)
2. [Deployment Methods](#deployment-methods)
3. [Prerequisites](#prerequisites)
4. [Basic Deployment](#basic-deployment)
5. [Advanced Features](#advanced-features)
6. [Event Sources](#event-sources)
7. [Performance Optimization](#performance-optimization)
8. [Cost Optimization](#cost-optimization)
9. [Security](#security)
10. [Troubleshooting](#troubleshooting)

---

## What is Lambda

AWS Lambda is a serverless compute service that runs code without provisioning servers.

### Key Benefits

- **No server management**
- **Auto-scaling** (0 to 1000s of concurrent executions)
- **Pay per use** (100ms billing increments)
- **Event-driven** architecture
- **Built-in fault tolerance**

### When to Use Lambda

✅ **Good for:**
- API backends
- Data processing
- Event-driven workflows
- Scheduled tasks
- Stream processing
- Webhooks

❌ **Not ideal for:**
- Long-running tasks (> 15 minutes)
- Stateful applications
- Low-latency requirements (< 10ms)
- Heavy CPU tasks (> 10GB memory need)

---

## Deployment Methods

### Method 1: Local Zip File

```hcl
module "function" {
  source = "../../modules/lambda"

  function_name = "my-function"
  filename      = "lambda.zip"  # Local file
  handler       = "index.handler"
  runtime       = "python3.11"
}
```

### Method 2: S3 Bucket

```hcl
module "function" {
  source = "../../modules/lambda"

  function_name = "my-function"
  s3_bucket     = "my-deployments"
  s3_key        = "lambda/my-function-v1.0.0.zip"
  handler       = "index.handler"
  runtime       = "python3.11"
}
```

### Method 3: Container Image

```hcl
module "function" {
  source = "../../modules/lambda"

  function_name = "ml-function"
  package_type  = "Image"
  image_uri     = "${module.ecr.repository_url}:latest"
  
  memory_size = 3008
}
```

---

## Prerequisites

### Create Deployment Package

#### Python

```bash
# Create function
cat > index.py << 'EOF'
def handler(event, context):
    return {
        'statusCode': 200,
        'body': 'Hello World!'
    }
EOF

# Package
zip lambda.zip index.py

# With dependencies
pip install -r requirements.txt -t package/
cd package && zip -r ../lambda.zip . && cd ..
zip -g lambda.zip index.py
```

#### Node.js

```bash
# Create function
cat > index.js << 'EOF'
exports.handler = async (event) => {
    return {
        statusCode: 200,
        body: 'Hello World!'
    };
};
EOF

# Package
zip lambda.zip index.js

# With dependencies
npm install
zip -r lambda.zip index.js node_modules/
```

---

## Basic Deployment

### Step 1: Create Function Code

See prerequisites above.

### Step 2: Configure Terraform

```hcl
module "api_function" {
  source = "../../modules/lambda"

  function_name = "api-handler"
  description   = "Handles API requests"
  
  filename = "lambda.zip"
  handler  = "index.handler"
  runtime  = "python3.11"

  memory_size = 256
  timeout     = 30

  create_role = true

  environment_variables = {
    ENV = "production"
  }

  tags = {
    Application = "api"
  }
}
```

### Step 3: Deploy

```bash
terraform init
terraform plan
terraform apply
```

### Step 4: Test

```bash
# Invoke function
aws lambda invoke \
  --function-name api-handler \
  --payload '{"key":"value"}' \
  response.json

# View response
cat response.json

# Check logs
aws logs tail /aws/lambda/api-handler --follow
```

---

## Advanced Features

### Aliases for Blue/Green Deployment

```hcl
module "function" {
  source = "../../modules/lambda"

  function_name = "api"
  publish       = true  # Required for aliases

  aliases = {
    live = {
      description      = "Production traffic"
      function_version = "1"
    }
    
    canary = {
      description      = "Canary deployment"
      function_version = "2"
      
      # 90% to v1, 10% to v2
      routing_config = {
        additional_version_weights = {
          "2" = 0.1
        }
      }
    }
  }
}
```

### Provisioned Concurrency

```hcl
# Eliminate cold starts
provisioned_concurrency = {
  prod = {
    qualifier             = "live"  # Alias name
    concurrent_executions = 5       # Keep 5 instances warm
  }
}
```

**Cost:** ~$13/month per warm instance

### Function URLs

```hcl
# Public HTTPS endpoint (no API Gateway needed)
create_function_url           = true
function_url_authorization_type = "NONE"  # Or AWS_IAM

function_url_cors = {
  allow_origins = ["https://myapp.com"]
  allow_methods = ["POST", "GET"]
  max_age       = 86400
}
```

### EFS Integration

```hcl
# Requires VPC configuration
vpc_config = {
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.lambda_sg.id, module.efs_sg.id]
}

# Mount EFS
file_system_config = {
  arn              = module.efs.access_point_arns["lambda"]
  local_mount_path = "/mnt/data"
}
```

---

## Event Sources

### SQS Queue

```hcl
event_source_mappings = {
  orders_queue = {
    event_source_arn = module.sqs.queue_arn
    batch_size       = 10
    enabled          = true
    
    maximum_batching_window_in_seconds = 5
    
    # Failure handling
    destination_config = {
      on_failure = {
        destination_arn = module.dlq.queue_arn
      }
    }
  }
}
```

### Kinesis Stream

```hcl
event_source_mappings = {
  data_stream = {
    event_source_arn  = module.kinesis.stream_arn
    starting_position = "LATEST"
    batch_size        = 100
    
    parallelization_factor             = 10
    maximum_batching_window_in_seconds = 5
    maximum_record_age_in_seconds      = 604800
    maximum_retry_attempts             = 3
    bisect_batch_on_function_error     = true
  }
}
```

### DynamoDB Stream

```hcl
event_source_mappings = {
  table_stream = {
    event_source_arn  = module.dynamodb.stream_arn
    starting_position = "TRIM_HORIZON"
    batch_size        = 50
    
    filter_criteria = {
      filters = [{
        pattern = jsonencode({
          eventName = ["INSERT", "MODIFY"]
        })
      }]
    }
  }
}
```

---

## Performance Optimization

### Memory Allocation

```hcl
# Test different memory sizes
# More memory = more CPU = potentially lower cost

# Example benchmarks (for CPU-intensive task):
# 128 MB: 10 seconds  = $0.000021
# 1024 MB: 1.5 seconds = $0.000025
# 1769 MB: 1 second    = $0.000017  ← Optimal!
```

### Use ARM64 (Graviton2)

```hcl
architectures = ["arm64"]
```

**Benefits:**
- 20% cost savings
- 19% better performance
- Same code (for most runtimes)

### Enable SnapStart (Java)

```hcl
snap_start_enabled = true
runtime            = "java17"
```

Reduces cold start time by up to 10x.

### Use Layers

```hcl
# Extract common dependencies
layers = [
  module.lambda_layer.layer_arn  # boto3, requests, etc.
]
```

**Benefits:**
- Smaller deployment packages
- Faster deployments
- Shared dependencies

---

## Cost Optimization

### Lambda Pricing (us-east-1)

**Compute:**
- **Requests:** $0.20 per 1M requests
- **Duration:** $0.0000166667 per GB-second

**Example:**
- 1M requests/month
- 128 MB memory
- 200ms average duration
- **Cost:** ~$5/month

### Optimization Strategies

#### 1. Use ARM64

```hcl
architectures = ["arm64"]  # 20% savings
```

#### 2. Right-Size Memory

```hcl
# Don't over-provision
# Use CloudWatch Insights to optimize
```

#### 3. Reduce Cold Starts

```hcl
# Option A: Provisioned concurrency ($$)
provisioned_concurrency = {...}

# Option B: Keep function warm (scheduled invocations)

# Option C: Increase memory (faster init)
memory_size = 512  # vs 128
```

#### 4. Use Reserved Concurrency

```hcl
# Prevent runaway costs
reserved_concurrent_executions = 100
```

#### 5. Shorter Log Retention

```hcl
log_retention_days = 7  # vs 30
```

---

## Security

### IAM Least Privilege

```hcl
attach_policy_arns = {
  dynamodb = "arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess"
  # Only what's needed
}
```

### VPC Integration

```hcl
vpc_config = {
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.lambda_sg.id]
}
```

### Encrypt Environment Variables

```hcl
# Lambda encrypts by default
# Use KMS for additional control
environment_variables = {
  DB_PASSWORD = "encrypted-value"  # Retrieve from Secrets Manager
}
```

### Encrypt Logs

```hcl
log_kms_key_id = module.kms.key_arn
```

### X-Ray Tracing

```hcl
tracing_mode = "Active"
```

---

## Troubleshooting

### High Duration

```bash
# Enable X-Ray
tracing_mode = "Active"

# View trace
aws xray get-trace-summaries \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s)
```

### Timeout Errors

```bash
# Increase timeout
timeout = 60  # seconds

# Or optimize code
# Or increase memory (more CPU)
```

### VPC Connectivity Issues

```bash
# Check:
# 1. NAT Gateway exists
# 2. Route tables configured
# 3. Security groups allow outbound
# 4. VPC endpoints for AWS services

# Test from Lambda
aws lambda invoke \
  --function-name test \
  --log-type Tail \
  --query 'LogResult' \
  --output text | base64 -d
```

---

## References

- [Lambda Module README](modules/lambda/README.md)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)

---

**End of Deployment Guide**

