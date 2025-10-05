# VPC Module

## Overview

This module creates a production-ready VPC with multi-AZ architecture following AWS Well-Architected Framework principles.

## Features

- **Multi-AZ Architecture**: Subnets across multiple availability zones
- **Three-Tier Network**: Public, Private (Application), and Database subnets
- **NAT Gateways**: High availability with one NAT per AZ (configurable)
- **VPC Endpoints**: Gateway endpoints for S3 and DynamoDB
- **VPC Flow Logs**: Network traffic logging for security and troubleshooting
- **DNS Support**: Enabled by default for service discovery

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                   │
│                                                             │
│  ┌──────────────────┐         ┌──────────────────┐        │
│  │  Public Subnet   │         │  Public Subnet   │        │
│  │   AZ-1 (10.0.1)  │         │   AZ-2 (10.0.2)  │        │
│  │                  │         │                  │        │
│  │   NAT Gateway    │         │   NAT Gateway    │        │
│  └────────┬─────────┘         └────────┬─────────┘        │
│           │                            │                   │
│  ┌────────▼─────────┐         ┌────────▼─────────┐        │
│  │ Private Subnet   │         │ Private Subnet   │        │
│  │  AZ-1 (10.0.11)  │         │  AZ-2 (10.0.12)  │        │
│  │  (Application)   │         │  (Application)   │        │
│  └──────────────────┘         └──────────────────┘        │
│                                                             │
│  ┌──────────────────┐         ┌──────────────────┐        │
│  │ Database Subnet  │         │ Database Subnet  │        │
│  │  AZ-1 (10.0.21)  │         │  AZ-2 (10.0.22)  │        │
│  └──────────────────┘         └──────────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## Usage

```hcl
module "vpc" {
  source = "../../../modules/vpc"

  vpc_name           = "production-vpc"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs  = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  database_subnet_cidrs = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

  enable_nat_gateway     = true
  one_nat_gateway_per_az = true
  single_nat_gateway     = false

  enable_flow_logs                = true
  flow_logs_retention_in_days     = 30

  enable_s3_endpoint       = true
  enable_dynamodb_endpoint = true

  environment = "production"

  tags = {
    Project   = "enterprise-infrastructure"
    ManagedBy = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vpc_name | Name of the VPC | string | n/a | yes |
| vpc_cidr | CIDR block for VPC | string | n/a | yes |
| availability_zones | List of availability zones | list(string) | n/a | yes |
| public_subnet_cidrs | CIDR blocks for public subnets | list(string) | n/a | yes |
| private_subnet_cidrs | CIDR blocks for private subnets | list(string) | n/a | yes |
| database_subnet_cidrs | CIDR blocks for database subnets | list(string) | [] | no |
| enable_nat_gateway | Enable NAT Gateway | bool | true | no |
| single_nat_gateway | Use single NAT Gateway | bool | false | no |
| one_nat_gateway_per_az | One NAT Gateway per AZ | bool | true | no |
| enable_flow_logs | Enable VPC Flow Logs | bool | true | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | ID of the VPC |
| vpc_cidr | CIDR block of the VPC |
| public_subnet_ids | List of public subnet IDs |
| private_subnet_ids | List of private subnet IDs |
| database_subnet_ids | List of database subnet IDs |
| nat_gateway_ids | List of NAT Gateway IDs |

## Cost Optimization

### Development Environments
```hcl
# Use single NAT Gateway for dev to save costs
single_nat_gateway     = true
one_nat_gateway_per_az = false
```

### Production Environments
```hcl
# Use one NAT per AZ for high availability
single_nat_gateway     = false
one_nat_gateway_per_az = true
```

## Security Considerations

1. **Network Segmentation**: Three-tier architecture isolates layers
2. **Private Subnets**: Application and database tiers not publicly accessible
3. **VPC Flow Logs**: Enabled for security monitoring and troubleshooting
4. **VPC Endpoints**: Reduces data transfer costs and improves security

## Best Practices Implemented

- ✅ Multi-AZ deployment for high availability
- ✅ Separate subnets for different tiers
- ✅ VPC Flow Logs enabled by default
- ✅ DNS resolution enabled
- ✅ Gateway endpoints for AWS services
- ✅ Proper tagging strategy
- ✅ Database subnet group for RDS

## Troubleshooting

### Issue: NAT Gateway Connection Timeouts

Check NAT Gateway health:
```bash
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=<vpc-id>"
```

### Issue: VPC Flow Logs Not Appearing

Verify CloudWatch Log Group and IAM role:
```bash
aws logs describe-log-groups --log-group-name-prefix "/aws/vpc/"
```

## Examples

See the `layers/networking/environments/` directory for complete examples.

## Authors

Platform Engineering Team

## License

Proprietary and confidential
