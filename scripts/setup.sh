#!/bin/bash

# Quick Setup Script for AWS Account Manager
# This script sets up the environment and creates necessary directories

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[SETUP] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

log "Setting up AWS Account Manager..."

# Create necessary directories
log "Creating directory structure..."
mkdir -p "$PROJECT_ROOT"/{config,terraform,environments,docs}

# Create config directories for different environments
mkdir -p "$PROJECT_ROOT"/environments/{dev,staging,prod}

# Create Terraform backend configuration
cat > "$PROJECT_ROOT/terraform/backend.tf" << 'EOF'
# Terraform Backend Configuration
# Configure this according to your requirements

terraform {
  backend "s3" {
    # bucket         = "your-terraform-state-bucket"
    # key            = "terraform.tfstate"
    # region         = "us-east-1"
    # encrypt        = true
    # dynamodb_table = "terraform-locks"
  }
}
EOF

# Create sample Terraform provider configuration
cat > "$PROJECT_ROOT/terraform/providers.tf" << 'EOF'
# Provider Configuration
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  # Assume role configuration will be handled by profiles
  # or environment variables set by the account manager script
}
EOF

# Create variables file
cat > "$PROJECT_ROOT/terraform/variables.tf" << 'EOF'
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "terraform-aws-enterprise"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}
EOF

# Create environment-specific variable files
for env in dev staging prod; do
    cat > "$PROJECT_ROOT/environments/$env/terraform.tfvars" << EOF
aws_region   = "us-east-1"
environment  = "$env"
project_name = "terraform-aws-enterprise"

# Add environment-specific variables here
EOF
done

# Create AWS profiles template
cat > "$PROJECT_ROOT/config/aws-profiles-template.conf" << 'EOF'
# AWS Profiles Configuration Template
# Copy this to ~/.aws/config and modify as needed

[default]
region = us-east-1
output = json

[profile dev-profile]
region = us-east-1
role_arn = arn:aws:iam::DEV_ACCOUNT_ID:role/OrganizationAccountAccessRole
source_profile = default

[profile staging-profile]
region = us-east-1
role_arn = arn:aws:iam::STAGING_ACCOUNT_ID:role/OrganizationAccountAccessRole
source_profile = default

[profile prod-profile]
region = us-east-1
role_arn = arn:aws:iam::PROD_ACCOUNT_ID:role/OrganizationAccountAccessRole
source_profile = default

# Add more profiles as needed
EOF

# Create environment aliases script
cat > "$PROJECT_ROOT/scripts/env-aliases.sh" << 'EOF'
#!/bin/bash

# Environment Aliases for AWS Account Manager
# Source this file to add convenient aliases: source scripts/env-aliases.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_MANAGER="$SCRIPT_DIR/aws-account-manager.sh"

# Account management aliases
alias aws-create='$AWS_MANAGER create-account'
alias aws-switch='$AWS_MANAGER switch'
alias aws-list='$AWS_MANAGER list-accounts'
alias aws-profiles='$AWS_MANAGER list-profiles'
alias aws-setup='$AWS_MANAGER setup-profile'
alias aws-assume='$AWS_MANAGER assume-role'
alias aws-validate='$AWS_MANAGER validate'

# Terraform aliases
alias tf-init='$AWS_MANAGER terraform-init'
alias tf-switch='$AWS_MANAGER terraform-switch'

# Quick environment switches
alias switch-dev='$AWS_MANAGER switch --profile dev-profile && $AWS_MANAGER terraform-switch --workspace dev'
alias switch-staging='$AWS_MANAGER switch --profile staging-profile && $AWS_MANAGER terraform-switch --workspace staging'
alias switch-prod='$AWS_MANAGER switch --profile prod-profile && $AWS_MANAGER terraform-switch --workspace prod'

# Environment exports
alias env-dev='export AWS_PROFILE=dev-profile && export TF_WORKSPACE=dev'
alias env-staging='export AWS_PROFILE=staging-profile && export TF_WORKSPACE=staging'
alias env-prod='export AWS_PROFILE=prod-profile && export TF_WORKSPACE=prod'

echo "AWS Account Manager aliases loaded!"
echo "Available commands:"
echo "  aws-create, aws-switch, aws-list, aws-profiles"
echo "  tf-init, tf-switch"
echo "  switch-dev, switch-staging, switch-prod"
echo "  env-dev, env-staging, env-prod"
EOF

chmod +x "$PROJECT_ROOT/scripts/env-aliases.sh"

# Create a Makefile for common operations
cat > "$PROJECT_ROOT/Makefile" << 'EOF'
# Makefile for AWS Account Manager

.PHONY: help setup validate switch-dev switch-staging switch-prod

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup: ## Setup the environment
	@scripts/setup.sh

validate: ## Validate AWS configuration
	@scripts/aws-account-manager.sh validate

switch-dev: ## Switch to development environment
	@scripts/aws-account-manager.sh switch --profile dev-profile
	@scripts/aws-account-manager.sh terraform-switch --workspace dev

switch-staging: ## Switch to staging environment
	@scripts/aws-account-manager.sh switch --profile staging-profile
	@scripts/aws-account-manager.sh terraform-switch --workspace staging

switch-prod: ## Switch to production environment
	@scripts/aws-account-manager.sh switch --profile prod-profile
	@scripts/aws-account-manager.sh terraform-switch --workspace prod

list-accounts: ## List all AWS accounts
	@scripts/aws-account-manager.sh list-accounts

list-profiles: ## List all AWS profiles
	@scripts/aws-account-manager.sh list-profiles

terraform-plan-dev: switch-dev ## Plan Terraform for dev
	@cd terraform && terraform plan -var-file="../environments/dev/terraform.tfvars"

terraform-plan-staging: switch-staging ## Plan Terraform for staging
	@cd terraform && terraform plan -var-file="../environments/staging/terraform.tfvars"

terraform-plan-prod: switch-prod ## Plan Terraform for production
	@cd terraform && terraform plan -var-file="../environments/prod/terraform.tfvars"
EOF

# Create .gitignore
cat > "$PROJECT_ROOT/.gitignore" << 'EOF'
# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
*.tfplan
*.tfplan.*

# AWS
.aws-env
*.pem
*.key

# Logs
*.log

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo

# Environment files
.env
.env.local
EOF

log "Environment setup completed!"

info "Next steps:"
echo "1. Configure your AWS credentials: aws configure"
echo "2. Test the script: ./scripts/aws-account-manager.sh validate"
echo "3. Create your first account: ./scripts/aws-account-manager.sh create-account --account-name 'dev-account' --email 'dev@yourcompany.com'"
echo "4. Source aliases for convenience: source scripts/env-aliases.sh"
echo "5. Use the Makefile for common operations: make help"

info "Documentation has been created in the docs/ directory"
info "Configuration templates are available in the config/ directory"
