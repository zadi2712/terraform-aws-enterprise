# VPC Endpoints Module - Quick Start Guide

Get started with VPC Endpoints in 5 minutes! 🚀

## Prerequisites

- Existing VPC with private subnets
- Terraform >= 1.5.0
- AWS CLI configured

## Step 1: Choose Your Use Case

### Option A: Basic Setup (Recommended for getting started)

```bash
cd examples/basic
cp basic.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
vpc_id             = "vpc-YOUR_VPC_ID"
vpc_cidr           = "10.0.0.0/16"
private_subnet_ids = ["subnet-XXX", "subnet-YYY"]
name_prefix        = "myapp-dev"
```

### Option B: Complete Enterprise Setup

```bash
cd examples/complete
cp complete.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your VPC ID.

### Option C: Advanced with Custom Policies

```bash
cd examples/advanced
cp advanced.tfvars.example terraform.tfvars
```

Edit all required variables in `terraform.tfvars`.

## Step 2: Get Your VPC Information

```bash
# Get VPC ID
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output table

# Get Private Subnet IDs
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-YOUR_VPC_ID" "Name=tag:Type,Values=private" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]' \
  --output table

# Get Route Table IDs (for gateway endpoints)
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=vpc-YOUR_VPC_ID" \
  --query 'RouteTables[*].[RouteTableId,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

## Step 3: Deploy

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply
```

## Step 4: Verify Deployment

```bash
# List all VPC endpoints in your VPC
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=vpc-YOUR_VPC_ID" \
  --query 'VpcEndpoints[*].[VpcEndpointId,ServiceName,State]' \
  --output table

# Test DNS resolution (from EC2 instance in private subnet)
nslookup ec2.us-east-1.amazonaws.com
# Should return private IP addresses (10.x.x.x)
```

## Step 5: Test Connectivity

SSH into an EC2 instance in your private subnet and run:

```bash
# Test EC2 endpoint
aws ec2 describe-instances --region us-east-1

# Test S3 endpoint
aws s3 ls

# Test Secrets Manager endpoint
aws secretsmanager list-secrets --region us-east-1
```

All commands should work without NAT Gateway! 🎉

## Common Configurations

### Minimal Cost (Dev Environment)

```hcl
endpoints = {
  ec2  = { service = "ec2" }
  logs = { service = "logs" }
  ssm  = { service = "ssm" }
  s3 = {
    service      = "s3"
    service_type = "Gateway"  # FREE!
  }
}
```

**Cost**: ~$22/month

### Recommended (Production)

```hcl
endpoints = {
  # Essential services
  ec2             = { service = "ec2" }
  ecr_api         = { service = "ecr.api" }
  ecr_dkr         = { service = "ecr.dkr" }
  ecs             = { service = "ecs" }
  logs            = { service = "logs" }
  kms             = { service = "kms" }
  secretsmanager  = { service = "secretsmanager" }
  ssm             = { service = "ssm" }
  
  # Gateway endpoints (FREE)
  s3 = {
    service      = "s3"
    service_type = "Gateway"
  }
  dynamodb = {
    service      = "dynamodb"
    service_type = "Gateway"
  }
}
```

**Cost**: ~$58/month

## Troubleshooting

### ❌ Cannot connect to AWS services

**Check 1**: Verify private DNS is enabled
```bash
aws ec2 describe-vpc-endpoints --vpc-endpoint-ids vpce-XXX \
  --query 'VpcEndpoints[0].PrivateDnsEnabled'
```

**Check 2**: Verify VPC DNS settings
```bash
aws ec2 describe-vpc-attribute --vpc-id vpc-XXX --attribute enableDnsHostnames
aws ec2 describe-vpc-attribute --vpc-id vpc-XXX --attribute enableDnsSupport
```

Both should be `true`.

**Check 3**: Verify security group
```bash
aws ec2 describe-security-groups --group-ids sg-XXX
```

Should allow inbound HTTPS (443) from VPC CIDR.

### ❌ High costs

**Solution 1**: Use Gateway endpoints for S3 and DynamoDB (FREE)
**Solution 2**: Deploy to single AZ in dev/test environments
**Solution 3**: Remove unused endpoints

### ❌ DNS not resolving to private IPs

**Fix**: Ensure VPC has DNS hostnames and DNS support enabled:

```bash
aws ec2 modify-vpc-attribute --vpc-id vpc-XXX --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id vpc-XXX --enable-dns-support
```

## Cost Estimation

Use the built-in cost estimator:

```bash
# From module root
make cost

# Or manually with infracost
infracost breakdown --path .
```

## Next Steps

1. ✅ Review the complete [README.md](README.md) for detailed documentation
2. ✅ Check the [examples/](examples/) for more configurations
3. ✅ Set up monitoring with CloudWatch
4. ✅ Configure VPC Flow Logs for audit
5. ✅ Update your runbooks with new architecture

## Useful Commands

```bash
# Format code
make fmt

# Validate configuration
make validate

# Generate documentation
make docs

# Run all checks
make all

# Clean up
make clean
```

## Support

- 📖 [Full Documentation](README.md)
- 🔧 [Troubleshooting Guide](README.md#monitoring-and-troubleshooting)
- 💡 [AWS VPC Endpoints Docs](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- 👥 Platform Engineering Team

---

**Time to First Endpoint**: < 5 minutes ⏱️

**Recommended First Deployment**: `examples/basic` 🎯
