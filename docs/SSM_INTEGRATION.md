# SSM Parameter Store Integration

## Overview

All Terraform layers now store their outputs in **AWS Systems Manager (SSM) Parameter Store** in addition to the traditional `terraform_remote_state` mechanism. This dual approach provides:

1. **Flexibility**: Access infrastructure data via Terraform remote state OR SSM API
2. **External Integration**: Non-Terraform tools can easily retrieve infrastructure information
3. **Runtime Configuration**: Applications can fetch configuration at runtime
4. **Audit Trail**: SSM provides built-in versioning and change tracking
5. **Cross-Account Access**: Easier to share infrastructure data across AWS accounts

## Parameter Naming Convention

All SSM parameters follow a consistent naming pattern:

```
/terraform/<project-name>/<environment>/<layer-name>/<output-key>
```

### Examples:

```
/terraform/myapp/dev/networking/vpc_id
/terraform/myapp/prod/compute/eks_cluster_endpoint
/terraform/myapp/qa/database/rds_endpoint
```

## Integrated Layers

All infrastructure layers now store outputs in SSM:

### ✅ Networking Layer
**Path**: `/terraform/<project>/<env>/networking/`

- `vpc_id` - VPC identifier
- `vpc_cidr` - VPC CIDR block
- `vpc_arn` - VPC ARN
- `public_subnet_ids` - Public subnet IDs (JSON array)
- `private_subnet_ids` - Private subnet IDs (JSON array)
- `database_subnet_ids` - Database subnet IDs (JSON array)
- `nat_gateway_ids` - NAT Gateway IDs (JSON array)
- `internet_gateway_id` - Internet Gateway ID
- `vpc_endpoints_security_group_id` - VPC Endpoints security group
- `network_summary` - Complete network configuration (JSON object)

### ✅ Security Layer
**Path**: `/terraform/<project>/<env>/security/`

- `kms_key_id` - KMS encryption key ID
- `kms_key_arn` - KMS encryption key ARN
- `kms_key_alias` - KMS key alias name
- `ecs_task_execution_role_arn` - ECS task execution IAM role
- `ecs_task_execution_role_name` - ECS task execution role name

### ✅ Compute Layer
**Path**: `/terraform/<project>/<env>/compute/`

- `ecr_repository_urls` - ECR repository URLs (JSON map)
- `ecr_repository_arns` - ECR repository ARNs (JSON map)
- `eks_cluster_endpoint` - EKS cluster API endpoint
- `eks_cluster_name` - EKS cluster name
- `eks_cluster_security_group_id` - EKS cluster security group
- `eks_oidc_provider_arn` - EKS OIDC provider ARN
- `ecs_cluster_id` - ECS cluster ID
- `ecs_cluster_arn` - ECS cluster ARN
- `alb_dns_name` - Application Load Balancer DNS
- `alb_arn` - Application Load Balancer ARN
- `bastion_public_ip` - Bastion host public IP

### ✅ Database Layer
**Path**: `/terraform/<project>/<env>/database/`

- `rds_endpoint` - RDS database endpoint
- `rds_instance_id` - RDS instance identifier
- `rds_security_group_id` - RDS security group ID
- `database_name` - Database name
- `master_username` - Database master username

### ✅ Storage Layer
**Path**: `/terraform/<project>/<env>/storage/`

- `application_bucket_id` - Application S3 bucket ID
- `application_bucket_arn` - Application S3 bucket ARN
- `application_bucket_name` - Application S3 bucket name
- `logs_bucket_id` - Logs S3 bucket ID
- `logs_bucket_arn` - Logs S3 bucket ARN

### ✅ DNS Layer
**Path**: `/terraform/<project>/<env>/dns/`

- `hosted_zone_id` - Route53 hosted zone ID
- `name_servers` - Route53 name servers (JSON array)
- `domain_name` - Domain name

### ✅ Monitoring Layer
**Path**: `/terraform/<project>/<env>/monitoring/`

- `sns_topic_arn` - SNS alerts topic ARN
- `sns_topic_name` - SNS topic name
- `log_group_name` - CloudWatch log group name
- `log_group_arn` - CloudWatch log group ARN

## Usage Examples

### 1. Terraform Data Source (Traditional)

```hcl
# Using terraform_remote_state (still works!)
data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "terraform-state-${var.environment}-${data.aws_caller_identity.current.account_id}"
    key    = "layers/networking/${var.environment}/terraform.tfstate"
    region = var.aws_region
  }
}

# Access outputs
resource "aws_instance" "example" {
  subnet_id = data.terraform_remote_state.networking.outputs.private_subnet_ids[0]
}
```

### 2. SSM Parameter Data Source (New Method)

```hcl
# Using SSM parameters
data "aws_ssm_parameter" "vpc_id" {
  name = "/terraform/${var.project_name}/${var.environment}/networking/vpc_id"
}

# Access value
resource "aws_instance" "example" {
  # SSM stores as JSON, use jsondecode if needed
  subnet_id = jsondecode(data.aws_ssm_parameter.private_subnet_ids.value)[0]
}
```

### 3. AWS CLI

```bash
# Get VPC ID
aws ssm get-parameter \
  --name "/terraform/myapp/prod/networking/vpc_id" \
  --query 'Parameter.Value' \
  --output text

# Get all networking parameters
aws ssm get-parameters-by-path \
  --path "/terraform/myapp/prod/networking/" \
  --recursive

# Get EKS cluster endpoint
aws ssm get-parameter \
  --name "/terraform/myapp/prod/compute/eks_cluster_endpoint" \
  --query 'Parameter.Value' \
  --output text
```

### 4. Python/Boto3

```python
import boto3
import json

ssm = boto3.client('ssm', region_name='us-east-1')

# Get single parameter
response = ssm.get_parameter(
    Name='/terraform/myapp/prod/networking/vpc_id'
)
vpc_id = json.loads(response['Parameter']['Value'])
print(f"VPC ID: {vpc_id}")

# Get all parameters for a layer
response = ssm.get_parameters_by_path(
    Path='/terraform/myapp/prod/networking/',
    Recursive=True
)

for param in response['Parameters']:
    print(f"{param['Name']}: {param['Value']}")
```

### 5. Application Runtime Configuration

```python
# Example: Django settings.py
import boto3
import json

def get_ssm_parameter(parameter_name):
    ssm = boto3.client('ssm')
    response = ssm.get_parameter(Name=parameter_name, WithDecryption=True)
    return json.loads(response['Parameter']['Value'])

# Get database endpoint at application startup
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'HOST': get_ssm_parameter('/terraform/myapp/prod/database/rds_endpoint').split(':')[0],
        'PORT': '5432',
        'NAME': get_ssm_parameter('/terraform/myapp/prod/database/database_name'),
        'USER': get_ssm_parameter('/terraform/myapp/prod/database/master_username'),
    }
}
```

### 6. Shell Script

```bash
#!/bin/bash

PROJECT="myapp"
ENVIRONMENT="prod"

# Function to get SSM parameter
get_parameter() {
    aws ssm get-parameter \
        --name "/terraform/${PROJECT}/${ENVIRONMENT}/$1" \
        --query 'Parameter.Value' \
        --output text
}

# Get infrastructure values
VPC_ID=$(get_parameter "networking/vpc_id")
EKS_CLUSTER=$(get_parameter "compute/eks_cluster_name")
RDS_ENDPOINT=$(get_parameter "database/rds_endpoint")

echo "VPC ID: $VPC_ID"
echo "EKS Cluster: $EKS_CLUSTER"
echo "RDS Endpoint: $RDS_ENDPOINT"
```

## Parameter Types and Tiers

### Parameter Types
- **String**: Most parameters are stored as String type
- **SecureString**: For sensitive data (requires KMS key)

### Parameter Tiers
- **Standard**: Parameters ≤ 4KB (free)
- **Advanced**: Parameters > 4KB (charges apply)

The module automatically selects the appropriate tier based on value size.

## Benefits by Use Case

### 1. **CI/CD Pipelines**
```yaml
# GitHub Actions example
- name: Get EKS cluster name
  run: |
    CLUSTER_NAME=$(aws ssm get-parameter \
      --name "/terraform/myapp/prod/compute/eks_cluster_name" \
      --query 'Parameter.Value' \
      --output text)
    echo "CLUSTER_NAME=$CLUSTER_NAME" >> $GITHUB_ENV

- name: Update kubeconfig
  run: |
    aws eks update-kubeconfig --name $CLUSTER_NAME --region us-east-1
```

### 2. **Container Applications**
```dockerfile
# Dockerfile
FROM python:3.11-slim

# Application can fetch config from SSM at runtime
COPY app.py /app/
CMD ["python", "/app/app.py"]
```

```python
# app.py
import boto3

def get_database_config():
    ssm = boto3.client('ssm')
    endpoint = ssm.get_parameter(
        Name='/terraform/myapp/prod/database/rds_endpoint'
    )['Parameter']['Value']
    return endpoint
```

### 3. **Lambda Functions**
```python
import boto3
import json

ssm = boto3.client('ssm')

def lambda_handler(event, context):
    # Get VPC configuration
    vpc_config = json.loads(
        ssm.get_parameter(
            Name='/terraform/myapp/prod/networking/network_summary'
        )['Parameter']['Value']
    )
    
    vpc_id = vpc_config['vpc_id']
    subnets = vpc_config['private_subnet_ids']
    
    # Use the configuration...
    return {"statusCode": 200}
```

### 4. **Cross-Account Access**
```hcl
# In a different AWS account/Terraform workspace
data "aws_ssm_parameter" "shared_vpc" {
  name = "/terraform/myapp/prod/networking/vpc_id"
  # Assuming cross-account IAM permissions are configured
}

resource "aws_vpc_peering_connection" "example" {
  vpc_id        = aws_vpc.local.id
  peer_vpc_id   = jsondecode(data.aws_ssm_parameter.shared_vpc.value)
  peer_owner_id = var.peer_account_id
}
```

## IAM Permissions Required

### For Reading Parameters

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/terraform/*"
    }
  ]
}
```

### For Terraform (Writing Parameters)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:PutParameter",
        "ssm:DeleteParameter",
        "ssm:GetParameter",
        "ssm:AddTagsToResource",
        "ssm:RemoveTagsFromResource"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/terraform/*"
    }
  ]
}
```

## Module Configuration

The SSM outputs module is configured in each layer's `main.tf`:

```hcl
module "ssm_outputs" {
  source = "../../../modules/ssm-outputs"

  project_name = var.project_name
  environment  = var.environment
  layer_name   = "networking"  # Changes per layer

  outputs = {
    vpc_id   = module.vpc.vpc_id
    vpc_cidr = module.vpc.vpc_cidr
    # ... more outputs
  }

  output_descriptions = {
    vpc_id   = "ID of the VPC"
    vpc_cidr = "CIDR block of the VPC"
    # ... more descriptions
  }

  tags = var.common_tags
}
```

## Migration Path

For existing deployments:

1. **No Breaking Changes**: `terraform_remote_state` still works
2. **Gradual Adoption**: Start using SSM for new integrations
3. **Testing**: Validate SSM parameters after deployment
4. **Monitoring**: Use CloudWatch to monitor SSM API usage

## Best Practices

1. **Use Descriptive Names**: Parameter names should be self-documenting
2. **Tag Appropriately**: Add tags for cost allocation and organization
3. **Version Control**: SSM automatically versions parameter changes
4. **Encryption**: Use SecureString for sensitive data
5. **Access Control**: Apply least-privilege IAM policies
6. **Monitoring**: Set up CloudWatch alarms for parameter access
7. **Documentation**: Keep parameter descriptions up-to-date

## Troubleshooting

### Parameter Not Found
```bash
# List all parameters
aws ssm describe-parameters \
  --parameter-filters "Key=Name,Values=/terraform/"

# Check parameter history
aws ssm get-parameter-history \
  --name "/terraform/myapp/prod/networking/vpc_id"
```

### Access Denied
```bash
# Check your IAM permissions
aws sts get-caller-identity

# Verify parameter exists and you have access
aws ssm get-parameter \
  --name "/terraform/myapp/prod/networking/vpc_id" \
  --query 'Parameter.Value'
```

### JSON Parsing Issues
```python
import json

# Always use json.loads for JSON-encoded values
value = json.loads(ssm_response['Parameter']['Value'])

# Handle both simple values and complex objects
if isinstance(value, list):
    # It's an array
    first_item = value[0]
elif isinstance(value, dict):
    # It's an object
    vpc_id = value['vpc_id']
else:
    # It's a simple value
    simple_value = value
```

## Cost Considerations

- **Standard Parameters**: Free (≤ 4KB, up to 10,000 parameters)
- **Advanced Parameters**: $0.05 per parameter per month
- **API Calls**: 
  - Standard throughput: Free (first 1M API calls/month)
  - Higher throughput: $0.05 per 10,000 API calls

Most infrastructure parameters use Standard tier (free).

## Summary

The SSM Parameter Store integration provides a modern, flexible way to share infrastructure data across your AWS environment. It complements the existing `terraform_remote_state` approach while enabling new use cases like application runtime configuration, CI/CD integration, and cross-account access.

**Key Advantages:**
- ✅ Dual access methods (Terraform + SSM API)
- ✅ Runtime configuration for applications
- ✅ CI/CD pipeline integration
- ✅ Cross-account data sharing
- ✅ Audit trail and versioning
- ✅ No migration required for existing code

---

**Last Updated**: October 13, 2025  
**Applies to**: All infrastructure layers (networking, security, compute, database, storage, dns, monitoring)
