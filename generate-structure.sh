#!/bin/bash

# Script to generate remaining Terraform structure
BASE_DIR="/Users/diego/terraform-aws-enterprise"

# Create backend.conf and terraform.tfvars for all layers and environments
LAYERS=("compute" "database" "storage" "security" "dns" "monitoring")
ENVIRONMENTS=("dev" "qa" "uat" "prod")

for layer in "${LAYERS[@]}"; do
  for env in "${ENVIRONMENTS[@]}"; do
    mkdir -p "${BASE_DIR}/layers/${layer}/environments/${env}"
    
    # Create backend.conf
    cat > "${BASE_DIR}/layers/${layer}/environments/${env}/backend.conf" << BACKEND
bucket         = "terraform-state-${env}-\${AWS_ACCOUNT_ID}"
key            = "layers/${layer}/${env}/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock-${env}"
encrypt        = true
BACKEND

    # Create terraform.tfvars based on environment
    cat > "${BASE_DIR}/layers/${layer}/environments/${env}/terraform.tfvars" << TFVARS
################################################################################
# ${layer^} Layer - ${env^^} Environment
# Auto-generated configuration file
################################################################################

# General Configuration
environment    = "${env}"
aws_region     = "us-east-1"
project_name   = "enterprise"

# Common Tags
common_tags = {
  Environment  = "${env}"
  Project      = "enterprise-infrastructure"
  ManagedBy    = "terraform"
  Layer        = "${layer}"
  CostCenter   = "engineering"
  Owner        = "platform-team"
  Compliance   = "pci-dss"
}
TFVARS
  done
done

echo "Structure generation complete!"
