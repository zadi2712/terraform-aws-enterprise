# Quick Start Guide

## 🚀 Get Started in 10 Minutes

This guide will help you deploy your first environment quickly.

## Prerequisites

Before you begin, ensure you have:

- [ ] AWS Account with admin access
- [ ] AWS CLI installed and configured
- [ ] Terraform >= 1.5.0 installed
- [ ] Git installed

## Step 1: Clone and Setup (2 minutes)

```bash
# Clone the repository
cd /path/to/terraform-aws-enterprise

# Verify tools are installed
make version

# Install additional tools if needed
# make install-tools
```

## Step 2: Configure AWS Account (3 minutes)

```bash
# Configure AWS CLI for dev environment
aws configure --profile dev
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-east-1
# Default output format: json

# Verify configuration
aws sts get-caller-identity --profile dev
```

## Step 3: Create Backend Infrastructure (2 minutes)

```bash
# This creates S3 buckets and DynamoDB tables for state management
make setup-backend

# Or manually
./scripts/setup-backend.sh
```

## Step 4: Deploy Networking Layer (3 minutes)

```bash
# Initialize Terraform
make init ENV=dev LAYER=networking

# Review what will be created
make plan ENV=dev LAYER=networking

# Apply changes
make apply ENV=dev LAYER=networking
```

## 🎉 Success!

You've deployed your first layer! The output will show:
- VPC ID
- Subnet IDs
- NAT Gateway IDs

## Next Steps

### Deploy All Layers

```bash
# Deploy complete infrastructure for dev environment
make dev-deploy
```

This will deploy in order:
1. Networking (VPC, Subnets, NAT Gateways)
2. Security (IAM, KMS)
3. DNS (Route53)
4. Database (RDS)
5. Storage (S3)
6. Compute (ECS)
7. Monitoring (CloudWatch)

### Check Infrastructure Health

```bash
# Run health check
make health-check ENV=dev
```

### View Outputs

```bash
# See all outputs from a layer
make output ENV=dev LAYER=networking
```

## Common Commands

### Development Workflow

```bash
# Format code
make fmt

# Validate configuration
make validate

# Run security scan
make security

# Run all tests
make test
```

### Managing Environments

```bash
# Deploy to QA
make qa-deploy

# Deploy to Production (requires confirmation)
make prod-deploy
```

### Troubleshooting

```bash
# View state
make state-list ENV=dev LAYER=networking

# Pull state for backup
make state-pull ENV=dev LAYER=networking

# Check logs
aws logs tail /aws/application/enterprise-dev --follow
```

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                 Internet/Users                   │
└──────────────────┬──────────────────────────────┘
                   │
          ┌────────▼────────┐
          │   CloudFront    │
          │   + Route53     │
          └────────┬────────┘
                   │
          ┌────────▼────────┐
          │   Application   │
          │   Load Balancer │
          └────────┬────────┘
                   │
    ┌──────────────┴──────────────┐
    │                             │
┌───▼────┐    VPC           ┌────▼───┐
│  ECS   │                  │  ECS   │
│ Tasks  │                  │ Tasks  │
│  AZ-1  │                  │  AZ-2  │
└───┬────┘                  └────┬───┘
    │                            │
┌───▼────────────────────────────▼───┐
│          RDS PostgreSQL             │
│          Multi-AZ + Replicas        │
└─────────────────────────────────────┘
```

## Customization

### Modify Resources

1. Edit layer-specific `terraform.tfvars`:
   ```bash
   vim layers/networking/environments/dev/terraform.tfvars
   ```

2. Plan and apply:
   ```bash
   make plan ENV=dev LAYER=networking
   make apply ENV=dev LAYER=networking
   ```

### Add New Resources

1. Create/modify module in `modules/` directory
2. Reference module in layer's `main.tf`
3. Deploy changes

## Environment-Specific Configuration

Each environment has different sizing:

| Resource | Dev | QA | UAT | Prod |
|----------|-----|-----|-----|------|
| EC2 Instance | t3.small | t3.medium | t3.large | t3.xlarge |
| RDS Instance | db.t3.small | db.t3.medium | db.r5.large | db.r5.xlarge |
| NAT Gateways | 1 | 2 | 3 | 3 |
| Multi-AZ | No | Yes | Yes | Yes |

## Cost Optimization Tips

### Development Environment
```bash
# Use single NAT Gateway
single_nat_gateway = true

# Use smaller instances
instance_type = "t3.small"

# Disable backups or short retention
backup_retention_days = 1
```

### Production Environment
```bash
# High availability
one_nat_gateway_per_az = true
enable_multi_az = true

# Longer backups
backup_retention_days = 30

# Enable monitoring
enable_performance_insights = true
container_insights_enabled = true
```

## Security Best Practices

1. **Never commit credentials**
   ```bash
   # Check before commit
   git secrets --scan
   ```

2. **Use Secrets Manager**
   ```bash
   # Store database password
   aws secretsmanager create-secret \
     --name /enterprise/dev/db-password \
     --secret-string "your-secure-password"
   ```

3. **Enable MFA for production**
   ```bash
   # Production deployments require MFA
   make prod-deploy
   # Will prompt for MFA token
   ```

## Support

### Documentation
- Full README: [README.md](README.md)
- Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Deployment Guide: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)
- Troubleshooting: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- Runbook: [docs/RUNBOOK.md](docs/RUNBOOK.md)

### Getting Help
- Check troubleshooting guide first
- Review AWS CloudWatch logs
- Contact platform team: platform-team@company.com
- Emergency: Page on-call engineer

## What's Next?

1. **Deploy to other environments**
   ```bash
   make qa-deploy
   make uat-deploy
   ```

2. **Set up monitoring**
   ```bash
   # Check CloudWatch dashboards
   aws cloudwatch list-dashboards
   ```

3. **Configure alerting**
   ```bash
   # Add email to SNS topic
   aws sns subscribe \
     --topic-arn <SNS_TOPIC_ARN> \
     --protocol email \
     --notification-endpoint your-email@company.com
   ```

4. **Review security**
   ```bash
   make security
   ```

5. **Customize for your needs**
   - Modify resource sizes
   - Add application-specific services
   - Configure domain names
   - Set up CI/CD pipeline

## Advanced Topics

### CI/CD Integration
```yaml
# Example GitHub Actions workflow
name: Terraform Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1
      - name: Deploy
        run: make dev-deploy
```

### Multi-Region Deployment
- Create separate layer directories for each region
- Use region-specific backend configuration
- Deploy with `make deploy-all ENV=dev REGION=us-west-2`

### Disaster Recovery
- Regular state backups: `make backup-state`
- RDS snapshots automated via retention policy
- Cross-region replication for critical S3 buckets

## FAQ

**Q: How much will this cost?**
A: Dev environment: ~$200-300/month, Prod: ~$1000-2000/month (varies by usage)

**Q: How long does deployment take?**
A: Initial deployment: ~30-45 minutes for all layers

**Q: Can I deploy multiple environments in the same account?**
A: Yes, environments are isolated by naming and tagging

**Q: How do I destroy everything?**
A: `make destroy ENV=dev LAYER=<layer>` for each layer in reverse order

**Q: Where are the state files stored?**
A: S3 buckets: `terraform-state-<env>-<account-id>`

## Congratulations! 🎉

You now have a production-ready AWS infrastructure!

For detailed information, see the [full documentation](README.md).
