# Security-Group Module

## Description

Security Groups

## Resources Created

- `aws_security_group`
- `aws_security_group_rule`

## Usage

```hcl
module "security-group" {
  source = "./modules/security-group"

  environment = "production"
  name        = "my-security-group"

  tags = {
    Environment = "production"
    Project     = "my-project"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name | `string` | n/a | yes |
| name | Resource name | `string` | n/a | yes |
| tags | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| id | Resource ID |
| arn | Resource ARN |

## Well-Architected Framework

This module implements AWS Well-Architected Framework best practices:

- **Operational Excellence**: Infrastructure as Code, automated deployments
- **Security**: Encryption at rest and in transit, least privilege access
- **Reliability**: Multi-AZ deployments, automated backups
- **Performance Efficiency**: Right-sizing, auto-scaling
- **Cost Optimization**: Resource tagging, lifecycle policies

## Examples

See the [examples](./examples) directory for complete usage examples.
