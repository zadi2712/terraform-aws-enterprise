# Lambda Module

## Description

Enterprise-grade AWS Lambda module for serverless functions supporting multiple deployment methods, VPC integration, event sources, layers, and comprehensive monitoring.

## Features

- **Multiple Package Types**: Zip files, S3, or container images
- **IAM Integration**: Automatic execution role creation
- **VPC Support**: Private subnet deployment
- **Event Sources**: SQS, Kinesis, DynamoDB Streams, SNS
- **Layers**: Shared code and dependencies
- **Aliases**: Blue/green deployments
- **Provisioned Concurrency**: Eliminate cold starts
- **Function URLs**: HTTPS endpoints
- **EFS Integration**: Persistent storage
- **X-Ray Tracing**: Distributed tracing
- **CloudWatch Logs**: Automatic log groups with encryption
- **Dead Letter Queues**: Error handling

## Resources Created

- `aws_lambda_function` - Lambda function
- `aws_iam_role` - Execution role (optional)
- `aws_iam_role_policy_attachment` - Policy attachments
- `aws_cloudwatch_log_group` - Log group
- `aws_lambda_alias` - Function aliases
- `aws_lambda_permission` - Invoke permissions
- `aws_lambda_event_source_mapping` - Event integrations
- `aws_lambda_function_url` - HTTPS endpoint
- `aws_lambda_provisioned_concurrency_config` - Warm instances

## Usage

### Basic Lambda Function

```hcl
module "hello_world" {
  source = "../../modules/lambda"

  function_name = "hello-world"
  description   = "Simple Hello World function"
  
  # Package
  filename = "lambda.zip"
  handler  = "index.handler"
  runtime  = "python3.11"

  # Resources
  memory_size = 128
  timeout     = 3

  # IAM
  create_role = true

  # Environment
  environment_variables = {
    ENVIRONMENT = "production"
  }

  tags = {
    Application = "demo"
  }
}
```

### Production Lambda with All Features

```hcl
module "api_handler" {
  source = "../../modules/lambda"

  function_name = "api-handler"
  description   = "API request handler"

  # Package from S3
  package_type     = "Zip"
  s3_bucket        = "my-lambda-deployments"
  s3_key           = "api-handler/v1.0.0.zip"
  s3_object_version = "xyz123"

  handler  = "index.handler"
  runtime  = "nodejs20.x"
  
  # Graviton for cost savings
  architectures = ["arm64"]

  # Resources
  memory_size = 512
  timeout     = 30

  # VPC integration
  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.lambda_sg.security_group_id]
  }

  # IAM
  create_role = true
  
  attach_policy_arns = {
    dynamodb = "arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess"
    s3       = module.iam_policy.s3_read_arn
  }

  # Environment
  environment_variables = {
    TABLE_NAME = module.dynamodb.table_name
    REGION     = "us-east-1"
  }

  # Logging
  create_log_group   = true
  log_retention_days = 30
  log_kms_key_id     = module.kms.key_arn

  # Tracing
  tracing_mode = "Active"

  # Dead letter queue
  dead_letter_config = {
    target_arn = module.sqs_dlq.queue_arn
  }

  # Aliases for blue/green
  publish = true
  
  aliases = {
    live = {
      description      = "Live production traffic"
      function_version = "1"
    }
  }

  # Provisioned concurrency (eliminate cold starts)
  provisioned_concurrency = {
    live = {
      qualifier             = "live"
      concurrent_executions = 5
    }
  }

  tags = {
    Environment = "production"
    Application = "api"
  }
}
```

### Container-Based Lambda

```hcl
module "container_function" {
  source = "../../modules/lambda"

  function_name = "ml-processor"
  description   = "ML model inference"

  # Container image from ECR
  package_type = "Image"
  image_uri    = "${module.ecr.repository_url}:latest"

  image_config = {
    command           = ["app.handler"]
    working_directory = "/app"
  }

  # Larger resources for ML
  memory_size = 3008
  timeout     = 300

  # Storage for model files
  ephemeral_storage_size = 2048

  create_role = true

  tags = {
    Workload = "ml"
  }
}
```

### Lambda with Event Sources

```hcl
module "stream_processor" {
  source = "../../modules/lambda"

  function_name = "stream-processor"
  
  filename = "processor.zip"
  handler  = "index.handler"
  runtime  = "python3.11"

  create_role = true
  
  attach_policy_arns = {
    kinesis = "arn:aws:iam::aws:policy/service-role/AWSLambdaKinesisExecutionRole"
  }

  # Event source mapping
  event_source_mappings = {
    kinesis_stream = {
      event_source_arn  = module.kinesis.stream_arn
      starting_position = "LATEST"
      batch_size        = 100
      
      maximum_batching_window_in_seconds = 5
      parallelization_factor             = 10
      
      filter_criteria = {
        filters = [{
          pattern = jsonencode({
            eventName = ["INSERT", "MODIFY"]
          })
        }]
      }
      
      destination_config = {
        on_failure = {
          destination_arn = module.sqs_dlq.queue_arn
        }
      }
    }
  }

  tags = {
    Purpose = "stream-processing"
  }
}
```

### Lambda with Function URL

```hcl
module "webhook" {
  source = "../../modules/lambda"

  function_name = "webhook-handler"
  
  filename = "webhook.zip"
  handler  = "index.handler"
  runtime  = "python3.11"

  create_role = true

  # Public HTTPS endpoint
  create_function_url           = true
  function_url_authorization_type = "NONE"  # Public endpoint
  
  function_url_cors = {
    allow_origins = ["https://myapp.com"]
    allow_methods = ["POST"]
    allow_headers = ["content-type"]
    max_age       = 86400
  }

  tags = {
    Type = "webhook"
  }
}
```

### Lambda with EFS

```hcl
module "efs_function" {
  source = "../../modules/lambda"

  function_name = "efs-processor"
  
  filename = "processor.zip"
  handler  = "index.handler"
  runtime  = "python3.11"

  # VPC required for EFS
  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.lambda_sg.id, module.efs_sg.id]
  }

  # EFS mount
  file_system_config = {
    arn              = module.efs.access_point_arns["lambda"]
    local_mount_path = "/mnt/data"
  }

  create_role = true

  tags = {
    Storage = "efs"
  }
}
```

## Inputs

### Required

| Name | Description | Type |
|------|-------------|------|
| function_name | Lambda function name | string |

### Package Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| package_type | Deployment package type | string | `"Zip"` |
| filename | Local zip file path | string | `null` |
| s3_bucket | S3 bucket with deployment package | string | `null` |
| s3_key | S3 object key | string | `null` |
| image_uri | ECR image URI | string | `null` |
| handler | Function entry point | string | `null` |
| runtime | Lambda runtime | string | `"python3.11"` |

### Resource Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| memory_size | Memory in MB (128-10240) | number | `128` |
| timeout | Timeout in seconds (1-900) | number | `3` |
| ephemeral_storage_size | Storage in MB (512-10240) | number | `null` |
| reserved_concurrent_executions | Reserved concurrency | number | `null` |

### IAM

| Name | Description | Type | Default |
|------|-------------|------|---------|
| create_role | Create execution role | bool | `true` |
| role_arn | Existing role ARN | string | `null` |
| attach_policy_arns | Additional policies | map(string) | `{}` |

### Advanced

| Name | Description | Type | Default |
|------|-------------|------|---------|
| vpc_config | VPC configuration | object | `null` |
| layers | Lambda layer ARNs | list(string) | `[]` |
| aliases | Function aliases | map(object) | `{}` |
| create_function_url | Create HTTPS endpoint | bool | `false` |
| event_source_mappings | Event sources | map(object) | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| function_arn | Lambda function ARN |
| function_name | Function name |
| function_invoke_arn | Invoke ARN (for API Gateway) |
| role_arn | Execution role ARN |
| log_group_name | CloudWatch log group name |
| function_url | Function URL (if created) |
| lambda_info | Complete function information |

## Runtimes

### Supported Runtimes

| Runtime | Version | Architecture | EOL Date |
|---------|---------|--------------|----------|
| python3.12 | Python 3.12 | x86_64, arm64 | - |
| python3.11 | Python 3.11 | x86_64, arm64 | - |
| nodejs20.x | Node.js 20 | x86_64, arm64 | - |
| nodejs18.x | Node.js 18 | x86_64, arm64 | - |
| java17 | Java 17 | x86_64, arm64 | - |
| java11 | Java 11 | x86_64, arm64 | - |
| dotnet8 | .NET 8 | x86_64, arm64 | - |
| ruby3.3 | Ruby 3.3 | x86_64, arm64 | - |
| go1.x | Go 1.x | x86_64, arm64 | - |

## Best Practices

### 1. Use ARM64 (Graviton)

```hcl
architectures = ["arm64"]  # 20% cheaper, 19% better performance
```

### 2. Right-Size Memory

```hcl
# Memory also determines CPU allocation
memory_size = 1769  # 1 vCPU
# 128-3008 MB = fractional vCPU
# 1769+ MB = 1+ vCPU
```

### 3. Enable X-Ray Tracing

```hcl
tracing_mode = "Active"
```

### 4. Use VPC Endpoints (if in VPC)

```hcl
# Avoid NAT Gateway costs
# Create VPC endpoints for:
# - S3, DynamoDB, SQS, SNS, etc.
```

### 5. Use Layers for Dependencies

```hcl
layers = [
  "arn:aws:lambda:us-east-1:123456789012:layer:my-dependencies:1"
]
```

### 6. Enable Provisioned Concurrency (Critical Paths)

```hcl
provisioned_concurrency = {
  prod = {
    qualifier             = "prod"
    concurrent_executions = 5  # Keep 5 warm
  }
}
```

### 7. Use Dead Letter Queues

```hcl
dead_letter_config = {
  target_arn = module.sqs_dlq.queue_arn
}
```

### 8. Encrypt Logs

```hcl
log_kms_key_id = module.kms.key_arn
```

## Memory vs Performance

| Memory (MB) | vCPU | Network | Use Case |
|-------------|------|---------|----------|
| 128 | 0.08 | Low | Simple tasks |
| 512 | 0.3 | Low | API handlers |
| 1024 | 0.6 | Medium | Data processing |
| 1769 | 1.0 | High | CPU-intensive |
| 3008 | 1.8 | High | Heavy workloads |
| 10240 | 6.0 | Very High | ML inference |

## Integration Examples

### With API Gateway

```hcl
# Lambda permission for API Gateway
permissions = {
  apigw = {
    principal  = "apigateway.amazonaws.com"
    source_arn = "${module.api_gateway.execution_arn}/*/*"
  }
}

# Use invoke_arn in API Gateway integration
```

### With SQS

```hcl
event_source_mappings = {
  sqs_queue = {
    event_source_arn = module.sqs.queue_arn
    batch_size       = 10
    enabled          = true
  }
}
```

### With S3

```hcl
permissions = {
  s3_invoke = {
    principal  = "s3.amazonaws.com"
    source_arn = module.s3.bucket_arn
  }
}

# Configure S3 bucket notification separately
```

### With EventBridge

```hcl
permissions = {
  eventbridge = {
    principal  = "events.amazonaws.com"
    source_arn = module.eventbridge_rule.rule_arn
  }
}
```

## Cost Optimization

### 1. Use ARM64

```hcl
architectures = ["arm64"]
# 20% cost savings vs x86_64
```

### 2. Right-Size Memory

```bash
# Use CloudWatch Insights to find optimal memory
# Under-provisioned = slow execution = higher cost
# Over-provisioned = wasted money
```

### 3. Use Shorter Log Retention

```hcl
log_retention_days = 7  # vs 30 days
```

### 4. Reserved Concurrency

```hcl
reserved_concurrent_executions = 10
# Prevent runaway costs from infinite loops
```

### 5. Use Layers

```hcl
# Share dependencies across functions
# Reduces deployment package size
layers = ["arn:aws:lambda:...:layer:common:1"]
```

## Troubleshooting

### Function Not Executing

```bash
# Check CloudWatch Logs
aws logs tail /aws/lambda/my-function --follow

# Invoke manually
aws lambda invoke \
  --function-name my-function \
  --payload '{"key":"value"}' \
  response.json

cat response.json
```

### VPC Timeout Issues

```bash
# Check:
# 1. NAT Gateway exists (for internet access)
# 2. VPC endpoints configured (S3, DynamoDB, etc.)
# 3. Security groups allow outbound traffic
```

### Permission Errors

```bash
# Check execution role
aws lambda get-function --function-name my-function \
  --query 'Configuration.Role'

# Check role policies
aws iam list-attached-role-policies --role-name my-function-role
```

## References

- [Lambda Developer Guide](https://docs.aws.amazon.com/lambda/)
- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Lambda Pricing](https://aws.amazon.com/lambda/pricing/)
- [Lambda Powertools](https://awslabs.github.io/aws-lambda-powertools-python/)

## Related Modules

- [VPC Module](../vpc/README.md)
- [IAM Module](../iam/README.md)
- [EFS Module](../efs/README.md)
- [ECR Module](../ecr/README.md)
