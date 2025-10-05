# Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the AWS infrastructure across all environments. Follow these procedures carefully to ensure a successful deployment.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Backend Configuration](#backend-configuration)
4. [Layer Deployment Order](#layer-deployment-order)
5. [Environment-Specific Deployments](#environment-specific-deployments)
6. [Post-Deployment Validation](#post-deployment-validation)
7. [Rollback Procedures](#rollback-procedures)

## Prerequisites

### Required Tools

```bash
# Terraform 1.5.0 or later
terraform -v
# Output: Terraform v1.5.0

# AWS CLI 2.x
aws --version
# Output: aws-cli/2.x.x

# jq for JSON processing
jq --version

# tflint for linting
tflint --version

# tfsec for security scanning
tfsec --version
```

### AWS Account Setup

1. **Create AWS Account Structure**:
   ```
   Root Account
   ├── Prod AWS Account (111111111111)
   ├── UAT AWS Account  (222222222222)
   ├── QA AWS Account   (333333333333)
   └── Dev AWS Account  (444444444444)
   ```

2. **Configure AWS CLI Profiles**:
   ```bash
   # ~/.aws/config
   [profile dev]
   region = us-east-1
   output = json
   role_arn = arn:aws:iam::444444444444:role/TerraformDeploymentRole
   source_profile = default

   [profile qa]
   region = us-east-1
   output = json
   role_arn = arn:aws:iam::333333333333:role/TerraformDeploymentRole
   source_profile = default

   [profile uat]
   region = us-east-1
   output = json
   role_arn = arn:aws:iam::222222222222:role/TerraformDeploymentRole
   source_profile = default

   [profile prod]
   region = us-east-1
   output = json
   role_arn = arn:aws:iam::111111111111:role/TerraformDeploymentRole
   source_profile = default
   mfa_serial = arn:aws:iam::111111111111:mfa/terraform-user
   ```

3. **Verify Access**:
   ```bash
   aws sts get-caller-identity --profile dev
   aws sts get-caller-identity --profile qa
   aws sts get-caller-identity --profile uat
   aws sts get-caller-identity --profile prod
   ```

## Pre-Deployment Checklist

### Before Starting Deployment

- [ ] AWS accounts created and configured
- [ ] IAM roles for Terraform created
- [ ] S3 buckets for state files created
- [ ] DynamoDB tables for state locking created
- [ ] Domain names registered in Route53
- [ ] SSL certificates requested in ACM
- [ ] Security scanning tools installed
- [ ] Team notified of deployment window
- [ ] Change request approved (for production)
- [ ] Backup of existing infrastructure (if applicable)

### Security Checks

```bash
# Run security scan before deployment
cd layers/networking
tfsec .

# Check for sensitive data
git secrets --scan

# Validate no hardcoded credentials
grep -r "AKIA" .
grep -r "password.*=" . | grep -v ".tfvars"
```

## Backend Configuration

### Step 1: Create S3 Buckets for State Files

```bash
# Set your AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create state buckets for each environment
for env in dev qa uat prod; do
  aws s3api create-bucket \
    --bucket terraform-state-${env}-${AWS_ACCOUNT_ID} \
    --region us-east-1 \
    --profile ${env}

  # Enable versioning
  aws s3api put-bucket-versioning \
    --bucket terraform-state-${env}-${AWS_ACCOUNT_ID} \
    --versioning-configuration Status=Enabled \
    --profile ${env}

  # Enable encryption
  aws s3api put-bucket-encryption \
    --bucket terraform-state-${env}-${AWS_ACCOUNT_ID} \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}' \
    --profile ${env}

  # Block public access
  aws s3api put-public-access-block \
    --bucket terraform-state-${env}-${AWS_ACCOUNT_ID} \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --profile ${env}

  # Enable server access logging
  aws s3api put-bucket-logging \
    --bucket terraform-state-${env}-${AWS_ACCOUNT_ID} \
    --bucket-logging-status \
    "LoggingEnabled={TargetBucket=terraform-state-${env}-${AWS_ACCOUNT_ID},TargetPrefix=logs/}" \
    --profile ${env}
done
```

### Step 2: Create DynamoDB Tables for State Locking

```bash
# Create lock tables for each environment
for env in dev qa uat prod; do
  aws dynamodb create-table \
    --table-name terraform-state-lock-${env} \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --tags Key=Environment,Value=${env} Key=ManagedBy,Value=terraform \
    --profile ${env}
done
```

### Step 3: Verify Backend Setup

```bash
# Verify S3 buckets
for env in dev qa uat prod; do
  echo "Checking ${env} bucket..."
  aws s3 ls s3://terraform-state-${env}-${AWS_ACCOUNT_ID} --profile ${env}
done

# Verify DynamoDB tables
for env in dev qa uat prod; do
  echo "Checking ${env} lock table..."
  aws dynamodb describe-table \
    --table-name terraform-state-lock-${env} \
    --profile ${env} \
    --query 'Table.TableStatus'
done
```

## Layer Deployment Order

### Critical: Deploy in This Exact Order

The layers have dependencies on each other. Deploy them in this sequence:

1. **Networking** → Foundation (VPC, Subnets, NAT)
2. **Security** → IAM, KMS, Secrets (depends on Networking)
3. **DNS** → Route53 (depends on Networking)
4. **Database** → RDS, DynamoDB (depends on Networking, Security)
5. **Storage** → S3, EFS (depends on Networking, Security)
6. **Compute** → EC2, ECS, EKS (depends on all above)
7. **Monitoring** → CloudWatch, SNS (depends on all above)

### Deployment Script

```bash
#!/bin/bash
# deploy-infrastructure.sh

set -e

ENVIRONMENT=$1
AWS_PROFILE=$ENVIRONMENT

if [ -z "$ENVIRONMENT" ]; then
  echo "Usage: ./deploy-infrastructure.sh <environment>"
  echo "Environment must be: dev, qa, uat, or prod"
  exit 1
fi

LAYERS=(
  "networking"
  "security"
  "dns"
  "database"
  "storage"
  "compute"
  "monitoring"
)

echo "🚀 Starting deployment for environment: $ENVIRONMENT"
echo "=================================================="

for layer in "${LAYERS[@]}"; do
  echo ""
  echo "📦 Deploying layer: $layer"
  echo "-----------------------------------"
  
  cd layers/${layer}/environments/${ENVIRONMENT}
  
  # Initialize Terraform
  echo "🔧 Initializing Terraform..."
  terraform init -backend-config=backend.conf -reconfigure
  
  # Validate configuration
  echo "✅ Validating configuration..."
  terraform validate
  
  # Plan changes
  echo "📋 Planning changes..."
  terraform plan -var-file=terraform.tfvars -out=tfplan
  
  # Apply changes
  echo "⚡ Applying changes..."
  terraform apply tfplan
  
  # Clean up plan file
  rm -f tfplan
  
  echo "✅ Layer $layer deployed successfully"
  
  cd ../../../../
done

echo ""
echo "🎉 All layers deployed successfully for $ENVIRONMENT!"
```

## Environment-Specific Deployments

### Development Environment

```bash
# Deploy to dev
cd /path/to/terraform-aws-enterprise

# Method 1: Use deployment script
chmod +x deploy-infrastructure.sh
./deploy-infrastructure.sh dev

# Method 2: Manual deployment
export AWS_PROFILE=dev

# 1. Networking
cd layers/networking/environments/dev
terraform init -backend-config=backend.conf
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# 2. Security
cd ../../security/environments/dev
terraform init -backend-config=backend.conf
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# Continue for all layers...
```

### QA Environment

```bash
# Deploy to qa
export AWS_PROFILE=qa
./deploy-infrastructure.sh qa
```

### UAT Environment

```bash
# Deploy to uat
export AWS_PROFILE=uat

# For UAT, add additional approval step
echo "Deploying to UAT environment. Proceed? (yes/no)"
read approval
if [ "$approval" == "yes" ]; then
  ./deploy-infrastructure.sh uat
fi
```

### Production Environment

```bash
# Deploy to production (requires MFA)
export AWS_PROFILE=prod

# Get MFA token
echo "Enter MFA token:"
read MFA_TOKEN

# Authenticate with MFA
aws sts get-session-token \
  --serial-number arn:aws:iam::111111111111:mfa/terraform-user \
  --token-code $MFA_TOKEN \
  --profile prod

# Deploy with additional safeguards
echo "⚠️  PRODUCTION DEPLOYMENT ⚠️"
echo "This will deploy to production. Type 'DEPLOY-TO-PRODUCTION' to continue:"
read confirmation

if [ "$confirmation" == "DEPLOY-TO-PRODUCTION" ]; then
  ./deploy-infrastructure.sh prod
else
  echo "Deployment cancelled"
  exit 1
fi
```

## Post-Deployment Validation

### Automated Validation Script

```bash
#!/bin/bash
# validate-deployment.sh

ENVIRONMENT=$1
AWS_PROFILE=$ENVIRONMENT

echo "🔍 Validating deployment for: $ENVIRONMENT"
echo "============================================"

# Check VPC
echo "Checking VPC..."
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Environment,Values=$ENVIRONMENT" \
  --query 'Vpcs[0].VpcId' \
  --output text \
  --profile $AWS_PROFILE)
echo "✅ VPC Found: $VPC_ID"

# Check Subnets
echo "Checking subnets..."
SUBNET_COUNT=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'length(Subnets)' \
  --output text \
  --profile $AWS_PROFILE)
echo "✅ Subnets Found: $SUBNET_COUNT"

# Check NAT Gateways
echo "Checking NAT Gateways..."
NAT_COUNT=$(aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
  --query 'length(NatGateways)' \
  --output text \
  --profile $AWS_PROFILE)
echo "✅ NAT Gateways: $NAT_COUNT"

# Check RDS Instances
echo "Checking RDS instances..."
RDS_COUNT=$(aws rds describe-db-instances \
  --query 'length(DBInstances[?TagList[?Key==`Environment` && Value==`'$ENVIRONMENT'`]])' \
  --output text \
  --profile $AWS_PROFILE)
echo "✅ RDS Instances: $RDS_COUNT"

# Check ECS Clusters
echo "Checking ECS clusters..."
ECS_COUNT=$(aws ecs list-clusters \
  --query 'length(clusterArns)' \
  --output text \
  --profile $AWS_PROFILE)
echo "✅ ECS Clusters: $ECS_COUNT"

# Check Load Balancers
echo "Checking Load Balancers..."
ALB_COUNT=$(aws elbv2 describe-load-balancers \
  --query 'length(LoadBalancers)' \
  --output text \
  --profile $AWS_PROFILE)
echo "✅ Load Balancers: $ALB_COUNT"

echo ""
echo "🎉 Validation complete!"
```

### Manual Validation Checklist

- [ ] VPC created with correct CIDR
- [ ] Public and private subnets created
- [ ] Internet Gateway attached
- [ ] NAT Gateways operational
- [ ] Route tables configured
- [ ] Security groups created
- [ ] IAM roles and policies applied
- [ ] KMS keys created
- [ ] RDS instances running
- [ ] S3 buckets created with policies
- [ ] ECS/EKS clusters operational
- [ ] Load balancers healthy
- [ ] DNS records created
- [ ] CloudWatch dashboards visible
- [ ] Alarms configured and active

## Rollback Procedures

### Automatic Rollback

```bash
# Rollback to previous state
cd layers/<layer>/environments/<environment>

# Show state history
terraform state list

# Rollback using state
terraform state pull > backup.tfstate
# Edit terraform.tfstate in S3 to previous version

# Or use version-specific state
terraform init -backend-config=backend.conf
terraform state pull > current.tfstate
# Restore previous version from S3 versioning
aws s3api get-object \
  --bucket terraform-state-${ENV}-${ACCOUNT_ID} \
  --key layers/${LAYER}/${ENV}/terraform.tfstate \
  --version-id <previous-version-id> \
  previous.tfstate

# Apply previous state
terraform apply
```

### Manual Rollback

```bash
# Destroy specific resources
terraform destroy -target=module.ecs_cluster

# Destroy entire layer
terraform destroy -var-file=terraform.tfvars

# Confirm destruction
echo "yes"
```

### Emergency Rollback

```bash
#!/bin/bash
# emergency-rollback.sh

ENVIRONMENT=$1
LAYER=$2

echo "⚠️  EMERGENCY ROLLBACK ⚠️"
echo "Environment: $ENVIRONMENT"
echo "Layer: $LAYER"
echo ""
echo "Type 'ROLLBACK' to proceed:"
read confirmation

if [ "$confirmation" == "ROLLBACK" ]; then
  cd layers/${LAYER}/environments/${ENVIRONMENT}
  terraform destroy -var-file=terraform.tfvars -auto-approve
  echo "✅ Rollback complete"
else
  echo "Rollback cancelled"
fi
```

## Troubleshooting Common Issues

### Issue: State Lock Error

```bash
# Error: Error acquiring the state lock
# Solution: Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### Issue: Resource Already Exists

```bash
# Import existing resource
terraform import <resource_type>.<resource_name> <resource_id>

# Example
terraform import aws_vpc.main vpc-12345678
```

### Issue: Timeout Errors

```bash
# Increase timeout in resource configuration
timeout {
  create = "60m"
  update = "60m"
  delete = "60m"
}
```

### Issue: Dependency Errors

```bash
# Add explicit dependencies
depends_on = [
  module.networking,
  module.security
]
```

## Deployment Best Practices

1. **Always Test in Dev First**: Never deploy directly to production
2. **Use Plan Before Apply**: Review changes before applying
3. **Enable Auto-Backup**: S3 versioning saves previous states
4. **Monitor During Deployment**: Watch CloudWatch for issues
5. **Deploy During Maintenance Windows**: Minimize user impact
6. **Have Rollback Plan Ready**: Know how to revert changes
7. **Document Changes**: Update documentation with each deployment
8. **Use Version Control**: Commit and push all changes
9. **Peer Review**: Have another team member review plans
10. **Incremental Changes**: Deploy small changes frequently

## Additional Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS Best Practices](https://aws.amazon.com/architecture/well-architected)
- [Internal Wiki](https://wiki.company.com/terraform)
- [Team Slack Channel](https://company.slack.com/terraform-support)
