# Development Environment - Networking Layer

## Overview

Cost-optimized networking configuration for the development environment. Designed for rapid iteration and testing with minimal infrastructure costs.

## Architecture

### Network Configuration
- **VPC CIDR**: 10.0.0.0/16
- **Availability Zones**: 2 (us-east-1a, us-east-1b)
- **Subnets**:
  - Public: 10.0.1.0/24, 10.0.2.0/24
  - Private: 10.0.11.0/24, 10.0.12.0/24
  - Database: 10.0.21.0/24, 10.0.22.0/24

### Cost Optimization
- **Single NAT Gateway**: Shared across all AZs (~$32/month savings)
- **VPC Flow Logs**: 7-day retention (minimal storage costs)
- **VPC Endpoints**: Enabled for testing

### Estimated Monthly Cost
- NAT Gateway: ~$32.40
- VPC Endpoints: ~$136.80
- VPC Flow Logs: ~$5
- **Total**: ~$174/month

## Deployment

### Prerequisites
1. AWS credentials configured
2. S3 bucket for state: `myapp-terraform-state-dev`
3. DynamoDB table: `terraform-state-lock`

### Initialize
```bash
cd layers/networking/environments/dev
terraform init -backend-config=backend.conf
```

### Plan
```bash
terraform plan -var-file=terraform.tfvars
```

### Apply
```bash
terraform apply -var-file=terraform.tfvars
```

### Destroy
```bash
terraform destroy -var-file=terraform.tfvars
```

## Configuration Details

### Key Features
- ✅ VPC with DNS support enabled
- ✅ Internet Gateway for public access
- ✅ Single NAT Gateway (cost-optimized)
- ✅ VPC Flow Logs (7-day retention)
- ✅ VPC Endpoints for AWS services
- ✅ Multi-AZ subnets for availability testing

### Security
- Private subnets for application workloads
- Database subnets isolated from internet
- VPC Flow Logs for traffic analysis
- Security groups managed by individual services

## Outputs

After deployment, you'll have access to:
- VPC ID and CIDR
- Subnet IDs (public, private, database)
- NAT Gateway ID
- VPC Endpoint IDs
- Route table IDs

## Notes

- This is a **cost-optimized** configuration
- Single NAT Gateway means reduced availability
- Suitable for development and testing only
- **Not recommended** for production use

## Support

For issues or questions:
- Review the main networking layer README
- Check Terraform state: `terraform show`
- Contact: DevOps Team
