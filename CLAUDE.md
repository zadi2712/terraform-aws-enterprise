# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is an enterprise-grade AWS infrastructure repository using Terraform with a **layered architecture** pattern. The infrastructure is organized into reusable modules and deployment layers across multiple environments (dev, qa, uat, prod).

## Architecture Pattern: Layered Infrastructure

The repository uses a strict **layered deployment approach** where infrastructure is organized into 7 layers that must be deployed in sequence:

1. **networking** - VPC, subnets, NAT gateways, Internet Gateway, VPC endpoints
2. **security** - KMS encryption keys (main, RDS, S3, EBS)
3. **dns** - Route53 hosted zones and records
4. **database** - RDS, DynamoDB
5. **storage** - S3 buckets, EFS file systems
6. **compute** - EC2, ECS, EKS, Lambda, ALB
7. **monitoring** - CloudWatch, SNS, alarms, dashboards

**Critical:** Each layer depends on the outputs of previous layers. Always maintain deployment order.

## Directory Structure

```
├── modules/          # Reusable Terraform modules (20 modules)
├── layers/           # Infrastructure layers (7 layers)
│   ├── networking/
│   ├── security/
│   ├── dns/
│   ├── database/
│   ├── storage/
│   ├── compute/
│   └── monitoring/
│       └── environments/  # Each layer has 4 environments
│           ├── dev/
│           │   ├── backend.conf      # S3 backend configuration
│           │   └── terraform.tfvars  # Environment-specific variables
│           ├── qa/
│           ├── uat/
│           └── prod/
├── scripts/         # Automation scripts
├── deploy.sh        # Full deployment automation
└── destroy.sh       # Full destruction automation
```

## Common Development Commands

### Terraform Version
This project requires **Terraform >= 1.13.0**. Always verify version before working:
```bash
terraform version
```

### Working with a Specific Layer/Environment

```bash
# Navigate to layer environment
cd layers/<layer>/environments/<env>

# Initialize (always use backend config)
terraform init -backend-config=backend.conf -upgrade

# Plan changes
terraform plan -var-file=terraform.tfvars

# Apply changes
terraform apply -var-file=terraform.tfvars

# View outputs
terraform output

# Destroy resources
terraform destroy -var-file=terraform.tfvars
```

### Using the Makefile

The repository includes a comprehensive Makefile for common tasks:

```bash
# View all available commands
make help

# Initialize a layer
make init LAYER=networking ENV=dev

# Plan changes
make plan LAYER=security ENV=dev

# Apply changes
make apply LAYER=compute ENV=prod

# View outputs
make output LAYER=networking ENV=dev

# Destroy a layer
make destroy LAYER=monitoring ENV=dev
```

### Full Environment Deployment

```bash
# Deploy all layers to an environment (in correct order)
./deploy.sh dev

# Or using make
make deploy-all ENV=dev

# Destroy all layers (in reverse order)
./destroy.sh dev
```

### Code Quality & Validation

```bash
# Format all Terraform files
terraform fmt -recursive
# Or: make fmt

# Validate configurations
make validate

# Run pre-commit hooks
pre-commit run --all-files

# Security scan (if tfsec installed)
make security-scan

# Linting (if tflint installed)
make lint
```

## Critical Architecture Decisions

### IAM Role Management (IMPORTANT)

**Decision:** IAM roles are managed by the modules that need them, NOT centralized in the security layer.

- **Security layer** manages ONLY KMS encryption keys
- **Each module** (ECS, Lambda, EC2, etc.) manages its own IAM roles
- **Rationale:** Better encapsulation, flexibility, and avoids naming conflicts

See ARCHITECTURE_DECISION_IAM.md for full details.

### Data Sharing Between Layers

Layers share data using **two complementary methods**:

1. **Terraform Remote State** (primary) - For layer-to-layer Terraform dependencies
2. **SSM Parameter Store** (secondary) - For runtime access and non-Terraform tools

All layer outputs are automatically stored in SSM with the pattern:
```
/terraform/<project-name>/<environment>/<layer-name>/<output-key>
```

Example:
```hcl
# Method 1: Remote state (in Terraform)
data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "terraform-state-${var.environment}-${data.aws_caller_identity.current.account_id}"
    key    = "layers/networking/${var.environment}/terraform.tfstate"
    region = var.aws_region
  }
}

# Method 2: SSM (for apps/scripts)
data "aws_ssm_parameter" "vpc_id" {
  name = "/terraform/${var.project_name}/${var.environment}/networking/vpc_id"
}
```

### State Management

- **Backend:** S3 with DynamoDB locking
- **State location:** `terraform-state-${environment}-${account_id}` bucket
- **State key pattern:** `layers/<layer>/${environment}/terraform.tfstate`
- **Locking table:** `terraform-state-lock` DynamoDB table
- **Encryption:** All state files encrypted with AES256

### Module Design Principles

1. Each module should be self-contained and reusable
2. Modules create their own IAM roles (not centralized)
3. Use feature flags (enable_* variables) for optional resources
4. All resources must be tagged using common_tags variable
5. Outputs should be comprehensive and include IDs, ARNs, and names

## Important Patterns

### Layer Main.tf Structure

Every layer follows this pattern:

```hcl
# 1. Terraform and provider configuration
terraform {
  required_version = ">= 1.13.0"
  backend "s3" { ... }
}

# 2. Module calls
module "vpc" {
  source = "../../../modules/vpc"
  # ...
}

# 3. SSM outputs module (ALWAYS last)
module "ssm_outputs" {
  source = "../../../modules/ssm-outputs"
  # Stores all outputs in SSM Parameter Store
  depends_on = [module.vpc, ...]
}
```

### Environment Configuration Pattern

Each environment has:
- `backend.conf` - S3 backend configuration
- `terraform.tfvars` - Environment-specific values

Different resource sizing per environment:
- **dev:** Small (t3.small, single-AZ)
- **qa:** Medium (t3.medium, multi-AZ)
- **uat:** Large (t3.large, multi-AZ)
- **prod:** XLarge (t3.xlarge+, multi-AZ, high availability)

### Tagging Strategy

All resources MUST include these tags via `common_tags`:

```hcl
common_tags = {
  Environment = "dev/qa/uat/prod"
  Project     = var.project_name
  ManagedBy   = "terraform"
  CostCenter  = "engineering"
  Owner       = "platform-team"
}
```

## Working with Modules

### Available Modules

Core infrastructure:
- `vpc` - VPC with public/private/database subnets
- `vpc-endpoints` - VPC PrivateLink endpoints for AWS services
- `security-group` - Security group management
- `kms` - KMS key management

Compute:
- `ec2` - EC2 instances with Auto Scaling
- `ecs` - ECS clusters and services (Fargate)
- `eks` - EKS Kubernetes clusters
- `lambda` - Lambda functions
- `alb` - Application Load Balancers

Database:
- `rds` - RDS PostgreSQL/MySQL
- `dynamodb` - DynamoDB tables

Storage:
- `s3` - S3 buckets with lifecycle policies
- `efs` - EFS file systems

Observability:
- `cloudwatch` - CloudWatch logs, alarms, dashboards
- `sns` - SNS topics for notifications

Other:
- `route53` - DNS management
- `cloudfront` - CDN distribution
- `ecr` - Container registry
- `iam` - IAM role patterns
- `ssm-outputs` - SSM Parameter Store integration

### Creating New Modules

When creating a new module, include:

1. `main.tf` - Resource definitions
2. `variables.tf` - Input variables with descriptions and validation
3. `outputs.tf` - Comprehensive outputs
4. `versions.tf` - Provider version constraints
5. `README.md` - Module documentation with examples

Use the existing modules as templates for consistency.

## Testing & Validation

### Pre-Deployment Checks

Before deploying changes:

```bash
# 1. Format code
terraform fmt -recursive

# 2. Validate syntax
cd layers/<layer>/environments/<env>
terraform init -backend-config=backend.conf
terraform validate

# 3. Plan and review
terraform plan -var-file=terraform.tfvars

# 4. Check for security issues (if tfsec available)
tfsec .
```

### Post-Deployment Validation

```bash
# Verify deployment
./scripts/validate.sh <environment>

# Check outputs
make output LAYER=<layer> ENV=<env>

# View logs
tail -f logs/deploy-<env>-*.log
```

## Deployment Workflow

### Standard Deployment Process

1. **Start with dev environment:**
   ```bash
   ./deploy.sh dev
   ```

2. **Test and validate in dev**

3. **Promote to QA:**
   ```bash
   # Update qa terraform.tfvars with appropriate values
   ./deploy.sh qa
   ```

4. **Promote to UAT and then PROD:**
   ```bash
   ./deploy.sh uat
   ./deploy.sh prod  # Requires typing "DEPLOY-TO-PRODUCTION" confirmation
   ```

### Deploying a Single Layer

When you only need to update one layer:

```bash
cd layers/<layer>/environments/<env>
terraform init -backend-config=backend.conf -upgrade
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### Handling State Locks

If a state lock gets stuck:

```bash
# View state list
terraform state list

# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

## Troubleshooting

### Common Issues

1. **"Backend configuration changed"**
   - Solution: Run `terraform init -backend-config=backend.conf -reconfigure`

2. **State lock timeout**
   - Check DynamoDB `terraform-state-lock` table
   - Verify no other terraform process is running
   - Force unlock if necessary (after confirming safety)

3. **Module not found errors**
   - Ensure you're in the correct directory
   - Verify module source path is relative to layer root
   - Run `terraform init -upgrade`

4. **Dependency errors between layers**
   - Verify previous layers are deployed
   - Check remote state configuration
   - Ensure outputs exist in SSM Parameter Store

5. **AWS credentials issues**
   - Verify: `aws sts get-caller-identity`
   - Check environment variables or AWS CLI configuration
   - Ensure correct AWS account and region

### Debugging Terraform

```bash
# Enable detailed logging
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform-debug.log

# Run terraform command
terraform plan -var-file=terraform.tfvars

# Disable logging
unset TF_LOG
unset TF_LOG_PATH
```

## Key Variables

### Global Variables (in all layers)

- `project_name` - Project identifier (default: "enterprise-platform")
- `environment` - Environment name (dev/qa/uat/prod)
- `aws_region` - AWS region (default: us-east-1)
- `common_tags` - Standard tags applied to all resources

### Layer-Specific Variables

**Networking:**
- `vpc_cidr` - VPC CIDR block
- `availability_zones` - List of AZs
- `enable_vpc_endpoints` - Enable VPC PrivateLink endpoints
- `enable_flow_logs` - Enable VPC Flow Logs

**Security:**
- `enable_key_rotation` - Enable automatic KMS key rotation
- `kms_deletion_window_in_days` - KMS key deletion window

**Compute:**
- `enable_ecs` - Enable ECS cluster
- `enable_eks` - Enable EKS cluster
- `enable_bastion` - Enable bastion host

## Documentation Resources

Quick reference guides (5 min reads):
- `ECS_QUICK_START.md` - Deploy containers quickly
- `KMS_QUICK_REFERENCE.md` - Encryption commands
- `CLOUDWATCH_QUICK_REFERENCE.md` - Monitoring setup
- `EC2_QUICK_REFERENCE.md` - Compute commands
- `EFS_QUICK_REFERENCE.md` - File storage commands
- `IAM_QUICK_REFERENCE.md` - IAM setup

Deployment guides (comprehensive):
- `KMS_DEPLOYMENT_GUIDE.md`
- `CLOUDWATCH_DEPLOYMENT_GUIDE.md`
- `EC2_DEPLOYMENT_GUIDE.md`
- `EFS_DEPLOYMENT_GUIDE.md`
- `IAM_DEPLOYMENT_GUIDE.md`

Architecture:
- `README.md` - Full architecture overview
- `START_HERE_COMPLETE.md` - Complete platform guide
- `ARCHITECTURE_DECISION_IAM.md` - IAM design decisions
- Module READMEs in `modules/*/README.md`

## Security Best Practices

1. **Never commit sensitive data:**
   - No AWS credentials in code
   - Use AWS Secrets Manager or SSM Parameter Store (SecureString)
   - Check `.gitignore` includes `*.tfvars` for sensitive values

2. **KMS encryption everywhere:**
   - RDS databases encrypted with `kms_rds` key
   - S3 buckets encrypted with `kms_s3` key
   - EBS volumes encrypted with `kms_ebs` key

3. **Network security:**
   - Private subnets for databases and applications
   - Public subnets only for load balancers
   - VPC endpoints for AWS service access (no internet)
   - Security groups with minimal required access

4. **IAM least privilege:**
   - Each service has its own role
   - Policies grant only necessary permissions
   - No wildcard permissions in production

## State Management Commands

```bash
# List all resources in state
terraform state list

# Show specific resource
terraform state show <resource_address>

# Move resource in state
terraform state mv <source> <destination>

# Remove resource from state (doesn't destroy)
terraform state rm <resource_address>

# Import existing resource
terraform import <resource_address> <resource_id>
```

## Cost Optimization

Estimated monthly costs by environment:
- **dev:** ~$55/month (minimal resources, single AZ)
- **qa:** ~$115/month (medium resources, multi-AZ)
- **uat:** ~$221/month (larger resources, multi-AZ)
- **prod:** ~$828/month (production-grade, HA)

To reduce costs in dev:
- Set `single_nat_gateway = true` in networking layer
- Disable unnecessary modules (set `enable_ecs = false`, etc.)
- Use smaller instance types
- Reduce backup retention periods

## Quick Task Reference

**Add a new environment:**
1. Copy existing environment directory
2. Update `backend.conf` with new state key
3. Update `terraform.tfvars` with environment values
4. Deploy: `./deploy.sh <new-env>`

**Add a new module:**
1. Create directory in `modules/<module-name>/`
2. Add main.tf, variables.tf, outputs.tf, versions.tf, README.md
3. Use module in appropriate layer
4. Document in layer's README

**Update a resource across all environments:**
1. Update module code
2. Test in dev: `cd layers/<layer>/environments/dev && terraform apply`
3. Promote to qa, uat, then prod sequentially

**View all outputs for an environment:**
```bash
cat outputs/<env>-*-outputs.json
```

**Export outputs to SSM:**
```bash
./scripts/export-outputs.sh <environment>
```

## Emergency Procedures

### Rollback Deployment

```bash
# If deployment fails, rollback to previous state
./scripts/rollback.sh <environment> <layer>
```

### Destroy Resources

```bash
# Destroy single layer
make destroy LAYER=<layer> ENV=<env>

# Destroy all layers (reverse order)
./destroy.sh <env>
```

### State Recovery

If state file is corrupted:
1. Check S3 bucket versioning for previous state
2. Download previous version
3. Restore to local `.terraform/` directory
4. Push corrected state: `terraform state push`

## Contributing Guidelines

When modifying this infrastructure:

1. Always work in dev environment first
2. Run `terraform fmt` before committing
3. Update module README.md if changing variables/outputs
4. Test full deployment in dev: `./deploy.sh dev`
5. Document any architecture changes
6. Update CLAUDE.md if workflow changes
7. Use descriptive commit messages following pattern: `<layer>: <description>`

Example commits:
- `networking: add VPC flow logs retention variable`
- `security: update KMS key deletion window to 30 days`
- `compute: enable ECS container insights`
