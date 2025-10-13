# SSM Outputs Module

This module stores Terraform layer outputs in AWS Systems Manager (SSM) Parameter Store, enabling dual-mode data sharing:
1. Traditional `terraform_remote_state` data sources
2. SSM Parameter Store retrieval (useful for non-Terraform tools, Lambda functions, ECS tasks, etc.)

## Purpose

While `terraform_remote_state` is the primary method for sharing data between Terraform layers, storing outputs in SSM Parameter Store provides additional benefits:

- **External Tool Access**: Non-Terraform tools (scripts, Lambda functions, ECS tasks) can retrieve infrastructure data
- **Runtime Configuration**: Applications can fetch configuration at runtime without Terraform access
- **Centralized Discovery**: All layer outputs are available in a single, well-organized location
- **Version Control**: SSM maintains parameter version history
- **Security**: Supports SecureString type for sensitive values with KMS encryption

## Usage

### Basic Example

```hcl
module "ssm_outputs" {
  source = "../../../modules/ssm-outputs"

  project_name = var.project_name
  environment  = var.environment
  layer_name   = "networking"
  
  outputs = {
    vpc_id             = module.vpc.vpc_id
    vpc_cidr           = module.vpc.vpc_cidr
    public_subnet_ids  = module.vpc.public_subnet_ids
    private_subnet_ids = module.vpc.private_subnet_ids
  }
  
  output_descriptions = {
    vpc_id             = "VPC ID for the environment"
    vpc_cidr           = "VPC CIDR block"
    public_subnet_ids  = "Public subnet IDs list"
    private_subnet_ids = "Private subnet IDs list"
  }
  
  tags = var.common_tags
}
```

### With Custom Parameter Prefix

```hcl
module "ssm_outputs" {
  source = "../../../modules/ssm-outputs"

  project_name     = var.project_name
  environment      = var.environment
  layer_name       = "security"
  parameter_prefix = "infra"  # Custom prefix instead of "terraform"
  
  outputs = {
    kms_key_id  = aws_kms_key.main.id
    kms_key_arn = aws_kms_key.main.arn
  }
  
  tags = var.common_tags
}
```

### With SecureString for Sensitive Data

```hcl
module "ssm_outputs_secure" {
  source = "../../../modules/ssm-outputs"

  project_name   = var.project_name
  environment    = var.environment
  layer_name     = "secrets"
  parameter_type = "SecureString"
  
  outputs = {
    db_password = random_password.db.result
    api_key     = random_password.api.result
  }
  
  tags = var.common_tags
}
```

## Parameter Naming Convention

Parameters are stored with the following path structure:

```
/{parameter_prefix}/{project_name}/{environment}/{layer_name}/{output_name}
```

Example paths:
- `/terraform/myproject/prod/networking/vpc_id`
- `/terraform/myproject/prod/security/kms_key_arn`
- `/terraform/myproject/dev/compute/eks_cluster_endpoint`

### Summary Parameter

When `create_summary_parameter = true` (default), an additional summary parameter is created:

```
/{parameter_prefix}/{project_name}/{environment}/{layer_name}/_summary
```

This contains all layer outputs in a single JSON-encoded parameter, useful for batch retrieval.

## Retrieving Values

### From Other Terraform Layers

Use the standard `terraform_remote_state` approach (recommended):

```hcl
data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "terraform-state-${var.environment}-${data.aws_caller_identity.current.account_id}"
    key    = "layers/networking/${var.environment}/terraform.tfstate"
    region = var.aws_region
  }
}

# Access outputs
vpc_id = data.terraform_remote_state.networking.outputs.vpc_id
```

### From SSM Parameter Store

#### Using AWS CLI

```bash
# Get a single parameter
aws ssm get-parameter \
  --name "/terraform/myproject/prod/networking/vpc_id" \
  --query "Parameter.Value" \
  --output text

# Get the summary parameter (all outputs)
aws ssm get-parameter \
  --name "/terraform/myproject/prod/networking/_summary" \
  --query "Parameter.Value" \
  --output text | jq .
```

#### Using Python (boto3)

```python
import boto3
import json

ssm = boto3.client('ssm')

# Get a single parameter
response = ssm.get_parameter(
    Name='/terraform/myproject/prod/networking/vpc_id'
)
vpc_id = json.loads(response['Parameter']['Value'])

# Get summary (all outputs)
response = ssm.get_parameter(
    Name='/terraform/myproject/prod/networking/_summary'
)
all_outputs = json.loads(response['Parameter']['Value'])
vpc_id = all_outputs['vpc_id']
subnets = all_outputs['private_subnet_ids']
```

#### In Lambda Function (Python)

```python
import boto3
import json
import os

ssm = boto3.client('ssm')

def lambda_handler(event, context):
    # Get networking outputs
    response = ssm.get_parameter(
        Name=f"/terraform/{os.environ['PROJECT_NAME']}/{os.environ['ENVIRONMENT']}/networking/_summary"
    )
    
    networking = json.loads(response['Parameter']['Value'])
    
    # Use the values
    vpc_id = networking['vpc_id']
    subnets = networking['private_subnet_ids']
    
    return {
        'statusCode': 200,
        'body': json.dumps(f'Using VPC: {vpc_id}')
    }
```

#### In ECS Task Definition

```json
{
  "containerDefinitions": [
    {
      "name": "app",
      "secrets": [
        {
          "name": "VPC_ID",
          "valueFrom": "/terraform/myproject/prod/networking/vpc_id"
        }
      ]
    }
  ]
}
```

## Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project | `string` | n/a | yes |
| environment | Environment name (e.g., dev, staging, prod) | `string` | n/a | yes |
| layer_name | Name of the Terraform layer | `string` | n/a | yes |
| outputs | Map of Terraform outputs to store | `any` | n/a | yes |
| output_descriptions | Map of output names to descriptions | `map(string)` | `{}` | no |
| parameter_prefix | Prefix for SSM parameter paths | `string` | `"terraform"` | no |
| parameter_type | Type of SSM parameter | `string` | `"String"` | no |
| create_summary_parameter | Create summary parameter with all outputs | `bool` | `true` | no |
| tags | Additional tags for SSM parameters | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| parameter_arns | ARNs of created SSM parameters |
| parameter_names | Names of created SSM parameters |
| parameter_paths | Full paths of created SSM parameters |
| summary_parameter_arn | ARN of the summary parameter |
| summary_parameter_name | Name of the summary parameter |
| parameter_count | Number of parameters created |

## Parameter Tiers

The module automatically determines the appropriate SSM parameter tier:

- **Standard Tier**: Used for parameters ≤ 4KB in size (free)
- **Advanced Tier**: Used for parameters > 4KB in size (charged per parameter per month)

## Best Practices

1. **Use terraform_remote_state as Primary**: Continue using `terraform_remote_state` for Terraform-to-Terraform data sharing
2. **SSM for External Access**: Use SSM parameters when non-Terraform tools need the data
3. **Consistent Naming**: Follow the established path convention for easy discovery
4. **Appropriate Parameter Type**: 
   - Use `String` for most values (default)
   - Use `SecureString` for sensitive data (encrypted with KMS)
   - Use `StringList` for comma-separated lists (rarely needed with JSON encoding)
5. **Documentation**: Provide clear descriptions for each output
6. **Summary Parameters**: Leverage summary parameters for batch retrieval
7. **IAM Permissions**: Ensure consuming resources have appropriate SSM permissions:
   ```json
   {
     "Effect": "Allow",
     "Action": [
       "ssm:GetParameter",
       "ssm:GetParameters",
       "ssm:GetParametersByPath"
     ],
     "Resource": "arn:aws:ssm:*:*:parameter/terraform/*"
   }
   ```

## Cost Considerations

- **Standard Parameters**: Free (up to 4KB)
- **Advanced Parameters**: $0.05 per parameter per month
- **API Calls**: Free tier includes 1M standard parameter API calls per month
- **SecureString**: No additional cost beyond standard KMS charges

## Limitations

- **Standard Tier**: Maximum value size of 4KB
- **Advanced Tier**: Maximum value size of 8KB
- **Parameter Name**: Maximum length of 2048 characters
- **API Rate Limits**: 3000 TPS (Transactions Per Second) per account per region

## Integration with Existing Layers

This module is designed to complement, not replace, `terraform_remote_state`. Both mechanisms work in parallel:

```
Layer Output → terraform_remote_state (Primary Method)
            └→ SSM Parameters (Secondary Access)
```

## Examples

See the layer implementations in `layers/` for complete examples of this module in use.

## License

This module is part of the enterprise Terraform infrastructure.
