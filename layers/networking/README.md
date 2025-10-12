# Networking Layer

## Overview

The networking layer establishes the foundational network infrastructure for the enterprise AWS environment, including VPC, subnets, routing, NAT gateways, and VPC endpoints. This layer implements AWS Well-Architected Framework best practices for security, reliability, and cost optimization.

## Architecture

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                          VPC (10.0.0.0/16)                                     │
│                                                                                 │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐   │
│  │  Availability Zone A │  │  Availability Zone B │  │  Availability Zone C │   │
│  │                      │  │                      │  │                      │   │
│  │  ┌────────────────┐ │  │  ┌────────────────┐ │  │  ┌────────────────┐ │   │
│  │  │ Public Subnet  │ │  │  │ Public Subnet  │ │  │  │ Public Subnet  │ │   │
│  │  │ 10.0.1.0/24    │ │  │  │ 10.0.2.0/24    │ │  │  │ 10.0.3.0/24    │ │   │
│  │  │  ┌───────┐     │ │  │  │  ┌───────┐     │ │  │  │  ┌───────┐     │ │   │
│  │  │  │  NAT  │     │ │  │  │  │  NAT  │     │ │  │  │  │  NAT  │     │ │   │
│  │  │  │Gateway│     │ │  │  │  │Gateway│     │ │  │  │  │Gateway│     │ │   │
│  │  │  └───▲───┘     │ │  │  │  └───▲───┘     │ │  │  │  └───▲───┘     │ │   │
│  │  └──────┼─────────┘ │  │  └──────┼─────────┘ │  │  └──────┼─────────┘ │   │
│  │         │           │  │         │           │  │         │           │   │
│  │  ┌──────▼─────────┐ │  │  ┌──────▼─────────┐ │  │  ┌──────▼─────────┐ │   │
│  │  │ Private Subnet │ │  │  │ Private Subnet │ │  │  │ Private Subnet │ │   │
│  │  │ 10.0.11.0/24   │ │  │  │ 10.0.12.0/24   │ │  │  │ 10.0.13.0/24   │ │   │
│  │  │  ┌─────────┐   │ │  │  │  ┌─────────┐   │ │  │  │  ┌─────────┐   │ │   │
│  │  │  │   App   │   │ │  │  │  │   App   │   │ │  │  │  │   App   │   │ │   │
│  │  │  │  Tier   │   │ │  │  │  │  Tier   │   │ │  │  │  │  Tier   │   │ │   │
│  │  │  └─────────┘   │ │  │  │  └─────────┘   │ │  │  │  └─────────┘   │ │   │
│  │  └────────────────┘ │  │  └────────────────┘ │  │  └────────────────┘ │   │
│  │                     │  │                     │  │                     │   │
│  │  ┌────────────────┐ │  │  ┌────────────────┐ │  │  ┌────────────────┐ │   │
│  │  │Database Subnet │ │  │  │Database Subnet │ │  │  │Database Subnet │ │   │
│  │  │ 10.0.21.0/24   │ │  │  │ 10.0.22.0/24   │ │  │  │ 10.0.23.0/24   │ │   │
│  │  │  ┌─────────┐   │ │  │  │  ┌─────────┐   │ │  │  │  ┌─────────┐   │ │   │
│  │  │  │   RDS   │   │ │  │  │  │   RDS   │   │ │  │  │  │   RDS   │   │ │   │
│  │  │  │ Replica │   │ │  │  │  │ Primary │   │ │  │  │  │ Replica │   │ │   │
│  │  │  └─────────┘   │ │  │  │  └─────────┘   │ │  │  │  └─────────┘   │ │   │
│  │  └────────────────┘ │  │  └────────────────┘ │  │  └────────────────┘ │   │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘   │
│                                                                                 │
│  ┌────────────────────────────────────────────────────────────────────────┐   │
│  │                         VPC Endpoints                                   │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐              │   │
│  │  │   EC2    │  │   ECR    │  │   ECS    │  │   ...    │              │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘              │   │
│  └────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Components

### 1. VPC (Virtual Private Cloud)
- **CIDR Block**: Configurable (default: 10.0.0.0/16)
- **DNS Support**: Enabled
- **DNS Hostnames**: Enabled
- **Tenancy**: Default
- **VPC Flow Logs**: Enabled for security monitoring

### 2. Subnets

#### Public Subnets
- Internet-facing resources (ALB, NAT Gateways)
- Auto-assign public IPv4
- Connected to Internet Gateway

#### Private Subnets
- Application tier (ECS, EKS, EC2)
- No direct internet access
- Connected to NAT Gateway for outbound traffic
- VPC endpoints for AWS services

#### Database Subnets
- RDS, ElastiCache, Redshift
- Isolated from direct internet
- Automatic subnet group creation

### 3. Gateways

#### Internet Gateway
- Single IGW per VPC
- Attached to public subnets

#### NAT Gateway
- **High Availability Mode** (Production): One NAT Gateway per AZ
- **Cost-Optimized Mode** (Dev/QA): Single NAT Gateway
- Elastic IP allocation

### 4. VPC Endpoints

#### Interface Endpoints (PrivateLink)
- EC2, ECS, ECR (API & Docker)
- KMS, Secrets Manager
- CloudWatch Logs, Monitoring, Events
- Systems Manager (SSM)
- RDS, ElastiCache
- SNS, SQS, Lambda
- STS, Auto Scaling
- And more...

#### Gateway Endpoints (Free)
- S3
- DynamoDB

### 5. Security Features

- **VPC Flow Logs**: CloudWatch Logs integration
- **Network ACLs**: Default allow (subnet-level)
- **Security Groups**: Managed per service
- **VPC Endpoint Policies**: Fine-grained access control
- **Private DNS**: Enabled for seamless AWS service access

## Usage

### Initial Deployment

```bash
# Navigate to networking layer
cd layers/networking

# Initialize Terraform
terraform init -backend-config=environments/prod/backend.conf

# Review planned changes
terraform plan -var-file=environments/prod/terraform.tfvars

# Apply configuration
terraform apply -var-file=environments/prod/terraform.tfvars
```

### Environment-Specific Deployment

#### Development
```bash
terraform apply -var-file=environments/dev/terraform.tfvars
```

#### Production
```bash
terraform apply -var-file=environments/prod/terraform.tfvars
```

## Configuration

### Environment Files

Each environment has two files in `environments/<env>/`:

1. **backend.conf** - S3 backend configuration
2. **terraform.tfvars** - Environment-specific variables

### Configuration Examples

#### Development Environment (Cost-Optimized)
```hcl
# environments/dev/terraform.tfvars
environment  = "dev"
aws_region   = "us-east-1"
project_name = "enterprise"

vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# Subnets
public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs  = ["10.0.11.0/24", "10.0.12.0/24"]
database_subnet_cidrs = ["10.0.21.0/24", "10.0.22.0/24"]

# Cost optimization for dev
enable_nat_gateway     = true
single_nat_gateway     = true   # Single NAT to save costs
one_nat_gateway_per_az = false

# VPC Features
enable_flow_logs         = true
flow_logs_retention_days = 7
enable_vpc_endpoints     = true

common_tags = {
  Environment = "dev"
  Project     = "enterprise-infrastructure"
}
```

#### Production Environment (High Availability)
```hcl
# environments/prod/terraform.tfvars
environment  = "prod"
aws_region   = "us-east-1"
project_name = "enterprise"

vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Subnets across 3 AZs
public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs  = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
database_subnet_cidrs = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]

# High availability
enable_nat_gateway     = true
single_nat_gateway     = false
one_nat_gateway_per_az = true   # One NAT per AZ

# VPC Features
enable_flow_logs         = true
flow_logs_retention_days = 30
enable_vpc_endpoints     = true

common_tags = {
  Environment = "production"
  Project     = "enterprise-infrastructure"
  Compliance  = "SOC2"
}
```

## VPC Endpoints Configuration

The layer creates comprehensive VPC endpoints for AWS services:

### Interface Endpoints Created

| Service | Purpose | Cost Impact |
|---------|---------|-------------|
| ec2 | EC2 API access | ~$7.20/month |
| ecr.api | ECR authentication | ~$7.20/month |
| ecr.dkr | Docker image pull | ~$7.20/month |
| ecs | ECS control plane | ~$7.20/month |
| ecs-telemetry | ECS metrics | ~$7.20/month |
| ssm | Systems Manager | ~$7.20/month |
| logs | CloudWatch Logs | ~$7.20/month |
| secretsmanager | Secrets retrieval | ~$7.20/month |
| kms | Encryption operations | ~$7.20/month |
| rds | RDS API access | ~$7.20/month |
| elasticache | ElastiCache API | ~$7.20/month |
| sns | SNS messaging | ~$7.20/month |
| sqs | SQS messaging | ~$7.20/month |
| lambda | Lambda invocation | ~$7.20/month |
| sts | AWS STS tokens | ~$7.20/month |
| elasticloadbalancing | ELB API | ~$7.20/month |
| autoscaling | Auto Scaling API | ~$7.20/month |
| monitoring | CloudWatch metrics | ~$7.20/month |
| events | EventBridge | ~$7.20/month |

### Gateway Endpoints Created (Free)

| Service | Purpose | Cost |
|---------|---------|------|
| s3 | S3 access | Free |
| dynamodb | DynamoDB access | Free |

### Cost Analysis

**Without VPC Endpoints (Using NAT Gateway)**:
- NAT Gateway: $0.045/hour/AZ + $0.045/GB
- 3 AZs x 24 hours x 30 days = $97.20/month (fixed)
- Data transfer: 1TB/month = $46.08/month
- **Total: ~$143.28/month**

**With VPC Endpoints**:
- Interface endpoints: 18 x $7.20/month = $129.60/month
- Data transfer: 1TB at $0.01/GB = $10.24/month
- Gateway endpoints: Free
- **Total: ~$139.84/month**

**Savings**: ~$3.44/month + Reduced latency + Enhanced security

*Note: Actual savings depend on traffic patterns. High data transfer volumes see greater savings.*

## Outputs

The networking layer provides comprehensive outputs for other layers:

### VPC Outputs
- `vpc_id` - VPC identifier
- `vpc_cidr` - VPC CIDR block
- `vpc_arn` - VPC ARN

### Subnet Outputs
- `public_subnet_ids` - List of public subnet IDs
- `private_subnet_ids` - List of private subnet IDs
- `database_subnet_ids` - List of database subnet IDs
- `database_subnet_group_name` - RDS subnet group name

### Gateway Outputs
- `nat_gateway_ids` - NAT Gateway IDs
- `internet_gateway_id` - Internet Gateway ID

### Route Table Outputs
- `public_route_table_ids` - Public route table IDs
- `private_route_table_ids` - Private route table IDs

### VPC Endpoint Outputs
- `vpc_endpoints_security_group_id` - Security group for VPC endpoints
- `vpc_endpoints_interface` - Interface endpoint IDs
- `vpc_endpoints_gateway` - Gateway endpoint IDs
- `vpc_endpoints_all` - All endpoint IDs
- `vpc_endpoints_count` - Count of endpoints

### Network Summary
- `network_summary` - Complete network configuration for other layers

## Using Outputs in Other Layers

```hcl
# In compute layer
data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "your-terraform-state-bucket"
    key    = "networking/terraform.tfstate"
    region = "us-east-1"
  }
}

module "ecs" {
  source = "../../modules/ecs"

  vpc_id             = data.terraform_remote_state.networking.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.networking.outputs.private_subnet_ids
  # ...
}
```

## Monitoring and Troubleshooting

### VPC Flow Logs

Access VPC Flow Logs in CloudWatch:

```bash
# View recent flow logs
aws logs tail /aws/vpcflowlogs/<log-group-name> --follow

# Filter for rejected traffic
aws logs filter-log-events \
  --log-group-name /aws/vpcflowlogs/<log-group-name> \
  --filter-pattern "[version, account, eni, source, destination, srcport, destport, protocol, packets, bytes, start, end, action=REJECT, logstatus]"
```

### Verify VPC Endpoints

```bash
# List all VPC endpoints
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'VpcEndpoints[].{Service:ServiceName,State:State,Type:VpcEndpointType}'

# Test endpoint connectivity from EC2 instance
nslookup ec2.us-east-1.amazonaws.com
# Should resolve to private IP (10.x.x.x)

# Test S3 gateway endpoint
aws s3 ls
# Traffic should route through endpoint (check Flow Logs)
```

### Common Issues

#### Issue: Cannot access AWS services from private subnets

**Solution:**
1. Verify VPC endpoints are created: `terraform output vpc_endpoints_all`
2. Check security group allows port 443
3. Verify private DNS is enabled
4. Confirm route tables have endpoint routes (for gateway endpoints)

#### Issue: High NAT Gateway costs

**Solution:**
1. Enable VPC endpoints: `enable_vpc_endpoints = true`
2. Use gateway endpoints for S3 and DynamoDB (free)
3. Consider interface endpoints for frequently accessed services

#### Issue: DNS resolution not working

**Solution:**
```hcl
# Verify these are enabled in VPC
enable_dns_hostnames = true
enable_dns_support   = true
```

## Security Best Practices

### 1. Network Segmentation
- Public subnets: Load balancers only
- Private subnets: Application tier
- Database subnets: Data tier only

### 2. Least Privilege Access
- Use VPC endpoint policies
- Restrict security group rules
- Enable VPC Flow Logs

### 3. Encryption in Transit
- Use VPC endpoints for private connectivity
- TLS 1.2+ for all communications

### 4. Monitoring and Auditing
- Enable VPC Flow Logs
- Monitor VPC endpoint usage
- Review security group changes

## Cost Optimization

### Development Environments
```hcl
# Use single NAT Gateway
single_nat_gateway = true

# Reduce flow log retention
flow_logs_retention_days = 7

# Consider disabling expensive endpoints
enable_vpc_endpoints = false  # Or selective endpoints
```

### Production Environments
```hcl
# High availability NAT
one_nat_gateway_per_az = true

# Comprehensive monitoring
flow_logs_retention_days = 30

# Full endpoint coverage
enable_vpc_endpoints = true
```

## Dependencies

### Module Dependencies
- **VPC Module** (`modules/vpc`)
- **VPC Endpoints Module** (`modules/vpc-endpoints`)

### AWS Service Dependencies
- AWS VPC
- AWS EC2 (NAT Gateways, IGW)
- AWS CloudWatch (Flow Logs)
- AWS S3 (Terraform state backend)
- AWS DynamoDB (State locking)

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.0 |

## Resources Created

- 1x VPC
- 1x Internet Gateway
- 1-3x NAT Gateways (depending on configuration)
- 6-9x Subnets (2-3 per type)
- 6-9x Route Tables
- 1x Database Subnet Group
- 1x VPC Flow Log
- 1x CloudWatch Log Group (for Flow Logs)
- 1x IAM Role (for Flow Logs)
- 18+x VPC Endpoints (if enabled)
- 1x Security Group (for VPC Endpoints)
- 2x S3/DynamoDB Gateway Endpoints (if enabled)

## Migration Guide

### From Existing VPC

If migrating from an existing VPC:

1. **Import existing resources:**
```bash
terraform import module.vpc.aws_vpc.this vpc-xxxxx
terraform import module.vpc.aws_internet_gateway.this igw-xxxxx
# Import other resources...
```

2. **Update configuration** to match existing setup

3. **Plan carefully:**
```bash
terraform plan -var-file=environments/prod/terraform.tfvars
```

4. **Apply incrementally** to avoid disruption

### Adding VPC Endpoints to Existing VPC

```hcl
# Enable endpoints in existing configuration
enable_vpc_endpoints = true

# Apply only VPC endpoint changes
terraform apply -target=module.vpc_endpoints -var-file=environments/prod/terraform.tfvars
```

## Examples

See environment configurations:
- [Development](environments/dev/terraform.tfvars)
- [QA](environments/qa/terraform.tfvars)
- [UAT](environments/uat/terraform.tfvars)
- [Production](environments/prod/terraform.tfvars)

## Support

For issues or questions:
- Review [troubleshooting](#monitoring-and-troubleshooting) section
- Check [VPC Endpoints documentation](../../modules/vpc-endpoints/README.md)
- Contact Platform Engineering team
- Create issue in repository

## References

- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [NAT Gateways](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)
- [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

---

**Last Updated**: October 2025
**Layer Version**: 1.0.0
**Maintained By**: Platform Engineering Team
