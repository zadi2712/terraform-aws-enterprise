# QA Environment - Networking Layer

## Overview

Production-like networking configuration for Quality Assurance testing. Balanced approach between cost and availability for integration and performance testing.

## Architecture

### Network Configuration
- **VPC CIDR**: 10.1.0.0/16
- **Availability Zones**: 3 (us-east-1a, us-east-1b, us-east-1c)
- **Subnets**:
  - Public: 10.1.1-3.0/24
  - Private: 10.1.11-13.0/24
  - Database: 10.1.21-23.0/24

### High Availability
- **NAT Gateways**: One per AZ (3 total)
- **VPC Flow Logs**: 30-day retention
- **VPC Endpoints**: Enabled for testing

### Estimated Monthly Cost
- NAT Gateways: ~$97.20 (3 × $32.40)
- VPC Endpoints: ~$136.80
- VPC Flow Logs: ~$10
- **Total**: ~$244/month

## Deployment

### Prerequisites
1. AWS credentials configured
2. S3 bucket: `myapp-terraform-state-qa`
3. DynamoDB table: `terraform-state-lock`

### Initialize
```bash
cd layers/networking/environments/qa
terraform init -backend-config=backend.conf
```

### Plan & Apply
```bash
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Configuration Details

### Key Features
- ✅ Multi-AZ with 3 availability zones
- ✅ One NAT Gateway per AZ
- ✅ VPC Flow Logs (30-day retention)
- ✅ VPC Endpoints for all AWS services
- ✅ Production-like high availability
- ✅ Suitable for integration testing

### Use Cases
- Integration testing
- Performance testing
- Load testing
- Pre-production validation

## Notes

- Production-like **high availability** setup
- Multiple NAT Gateways for redundancy
- Suitable for comprehensive QA testing
- Recommended for pre-production validation

## Next Steps

After networking deployment:
1. Deploy compute layer (ECS/EKS)
2. Deploy database layer (RDS)
3. Configure application services
4. Run integration tests
