# Quick Start Guide

## 🚀 Getting Started in 15 Minutes

This guide will help you deploy your first environment quickly.

## Prerequisites

```bash
# Install required tools
brew install terraform awscli

# Verify installations
terraform version  # Should be >= 1.5.0
aws --version      # Should be >= 2.0
```

## Step 1: Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Or use environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Verify access
aws sts get-caller-identity
```

## Step 2: Set Up Backend (One-Time Setup)

```bash
# Get your AWS Account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket terraform-state-dev-${AWS_ACCOUNT_ID} \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket terraform-state-dev-${AWS_ACCOUNT_ID} \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket terraform-state-dev-${AWS_ACCOUNT_ID} \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock-dev \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## Step 3: Deploy Networking Layer

```bash
cd layers/networking/environments/dev

# Update backend.conf with your account ID
sed -i '' "s/\${AWS_ACCOUNT_ID}/${AWS_ACCOUNT_ID}/g" backend.conf

# Initialize Terraform
terraform init -backend-config=backend.conf

# Review what will be created
terraform plan -var-file=terraform.tfvars

# Apply the configuration
terraform apply -var-file=terraform.tfvars

# Save outputs for later use
terraform output -json > networking-outputs.json
```

## Step 4: Deploy Security Layer

```bash
cd ../../security/environments/dev

# Update backend.conf
sed -i '' "s/\${AWS_ACCOUNT_ID}/${AWS_ACCOUNT_ID}/g" backend.conf

# Initialize and apply
terraform init -backend-config=backend.conf
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Step 5: Deploy Remaining Layers

```bash
# Deploy in order
for layer in dns database storage compute monitoring; do
  echo "Deploying $layer layer..."
  cd ../../${layer}/environments/dev
  sed -i '' "s/\${AWS_ACCOUNT_ID}/${AWS_ACCOUNT_ID}/g" backend.conf
  terraform init -backend-config=backend.conf
  terraform apply -var-file=terraform.tfvars -auto-approve
done
```

## Step 6: Verify Deployment

```bash
# Check VPC
aws ec2 describe-vpcs \
  --filters "Name=tag:Environment,Values=dev" \
  --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Check subnets
aws ec2 describe-subnets \
  --filters "Name=tag:Environment,Values=dev" \
  --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Check ECS cluster
aws ecs list-clusters

# Check RDS (if created)
aws rds describe-db-instances \
  --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address]' \
  --output table
```

## Common Customizations

### Change Instance Sizes

Edit `terraform.tfvars`:
```hcl
instance_type     = "t3.medium"  # Instead of t3.small
rds_instance_type = "db.t3.medium"
```

### Enable/Disable Multi-AZ

```hcl
enable_multi_az = true  # For production
enable_multi_az = false # For dev to save costs
```

### Add Custom Tags

```hcl
common_tags = {
  Environment  = "dev"
  Project      = "my-project"
  Team         = "platform"
  CostCenter   = "engineering"
  Owner        = "john.doe@company.com"
}
```

## Automated Deployment Script

```bash
#!/bin/bash
# deploy-dev.sh

set -e

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LAYERS=(networking security dns database storage compute monitoring)

echo "🚀 Deploying DEV environment"
echo "AWS Account: $AWS_ACCOUNT_ID"
echo ""

for layer in "${LAYERS[@]}"; do
  echo "📦 Deploying $layer layer..."
  cd layers/${layer}/environments/dev
  
  # Update backend config
  sed "s/\${AWS_ACCOUNT_ID}/${AWS_ACCOUNT_ID}/g" backend.conf > backend.conf.tmp
  mv backend.conf.tmp backend.conf
  
  # Deploy
  terraform init -backend-config=backend.conf -reconfigure
  terraform apply -var-file=terraform.tfvars -auto-approve
  
  cd ../../../../
  echo "✅ $layer layer deployed"
  echo ""
done

echo "🎉 DEV environment deployed successfully!"
```

Make it executable and run:
```bash
chmod +x deploy-dev.sh
./deploy-dev.sh
```

## Cost Estimation

### Development Environment (~$200-300/month)
- VPC & Networking: ~$45/month (1 NAT Gateway)
- RDS t3.small: ~$30/month
- ECS Fargate (2 tasks): ~$50/month
- ALB: ~$23/month
- S3 & CloudWatch: ~$20/month
- Data Transfer: ~$30/month

### Production Environment (~$1000-1500/month)
- VPC & Networking: ~$135/month (3 NAT Gateways)
- RDS r5.xlarge Multi-AZ: ~$500/month
- ECS Fargate (10 tasks): ~$250/month
- ALB: ~$23/month
- CloudFront: ~$50/month
- S3, CloudWatch, Misc: ~$100/month

## Destroying Resources

**⚠️ WARNING: This will delete all resources!**

```bash
# Destroy in reverse order
LAYERS=(monitoring compute storage database dns security networking)

for layer in "${LAYERS[@]}"; do
  echo "Destroying $layer layer..."
  cd layers/${layer}/environments/dev
  terraform destroy -var-file=terraform.tfvars -auto-approve
  cd ../../../../
done
```

## Troubleshooting Quick Fixes

### State Lock Issue
```bash
terraform force-unlock <LOCK_ID>
```

### Resource Already Exists
```bash
# Import the resource
terraform import module.vpc.aws_vpc.main vpc-xxxxx
```

### Need to Start Over
```bash
# Destroy everything
terraform destroy -auto-approve

# Remove state
rm -rf .terraform*
rm terraform.tfstate*

# Re-initialize
terraform init -backend-config=backend.conf
```

## Next Steps

1. **Customize Variables**: Edit `terraform.tfvars` files for your needs
2. **Add Applications**: Deploy your applications to ECS
3. **Set Up Monitoring**: Configure CloudWatch dashboards and alarms
4. **Enable CI/CD**: Integrate with GitHub Actions or Jenkins
5. **Deploy to QA**: Repeat process for QA environment
6. **Production Deployment**: Follow production checklist in DEPLOYMENT.md

## Useful Commands

```bash
# Show current state
terraform show

# List all resources
terraform state list

# Get outputs
terraform output

# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Show plan without applying
terraform plan -var-file=terraform.tfvars

# Apply specific module
terraform apply -target=module.vpc

# Refresh state
terraform refresh

# Show dependency graph
terraform graph | dot -Tpng > graph.png
```

## Getting Help

- 📚 Full Documentation: `docs/`
- 🔧 Troubleshooting: `docs/TROUBLESHOOTING.md`
- 📖 Runbook: `docs/RUNBOOK.md`
- 🏗️ Architecture: `docs/ARCHITECTURE.md`

## Security Checklist

Before deploying to production:

- [ ] Change default passwords in `terraform.tfvars`
- [ ] Enable MFA on AWS account
- [ ] Review security group rules
- [ ] Enable CloudTrail
- [ ] Set up AWS Config
- [ ] Configure backup retention
- [ ] Test disaster recovery
- [ ] Enable deletion protection on critical resources

## Support

- Internal Wiki: https://wiki.company.com/terraform
- Team Slack: #platform-engineering
- Email: platform-team@company.com

---

**Ready to deploy?** Start with Step 1 above! 🚀
