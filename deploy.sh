#!/bin/bash
################################################################################
# Enterprise AWS Infrastructure Deployment Script
# Description: Automated deployment for all layers in specified environment
# Usage: ./deploy.sh <environment>
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVIRONMENT=${1:-dev}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|qa|uat|prod)$ ]]; then
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo "Usage: $0 <environment>"
    echo "Environment must be: dev, qa, uat, or prod"
    exit 1
fi

# Validate AWS credentials
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}❌ AWS credentials not configured${NC}"
    echo "Please run: aws configure"
    exit 1
fi

# Deployment layers in order
LAYERS=(
    "networking"
    "security"
    "dns"
    "database"
    "storage"
    "compute"
    "monitoring"
)

# Function to print section header
print_header() {
    echo ""
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo ""
}

# Function to print success message
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Function to print error message
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to print warning message
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to print info message
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Confirmation for production
if [ "$ENVIRONMENT" == "prod" ]; then
    print_warning "You are about to deploy to PRODUCTION!"
    echo -n "Type 'DEPLOY-TO-PRODUCTION' to continue: "
    read -r confirmation
    if [ "$confirmation" != "DEPLOY-TO-PRODUCTION" ]; then
        print_error "Deployment cancelled"
        exit 1
    fi
fi

# Main deployment
print_header "AWS Infrastructure Deployment - $ENVIRONMENT"
print_info "AWS Account ID: $AWS_ACCOUNT_ID"
print_info "Region: us-east-1"
print_info "Layers to deploy: ${#LAYERS[@]}"
echo ""

# Create log directory
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).log"

# Function to deploy a layer
deploy_layer() {
    local layer=$1
    local layer_dir="$SCRIPT_DIR/layers/${layer}/environments/${ENVIRONMENT}"
    
    print_info "Deploying layer: $layer"
    
    # Check if directory exists
    if [ ! -d "$layer_dir" ]; then
        print_error "Layer directory not found: $layer_dir"
        return 1
    fi
    
    cd "$layer_dir"
    
    # Update backend config with account ID
    if [ -f "backend.conf" ]; then
        sed "s/\${AWS_ACCOUNT_ID}/${AWS_ACCOUNT_ID}/g" backend.conf > backend.conf.tmp
        mv backend.conf.tmp backend.conf
    fi
    
    # Initialize Terraform
    print_info "  Initializing Terraform..."
    if ! terraform init -backend-config=backend.conf -reconfigure >> "$LOG_FILE" 2>&1; then
        print_error "  Failed to initialize Terraform for $layer"
        return 1
    fi
    
    # Validate configuration
    print_info "  Validating configuration..."
    if ! terraform validate >> "$LOG_FILE" 2>&1; then
        print_error "  Validation failed for $layer"
        return 1
    fi
    
    # Plan
    print_info "  Planning changes..."
    if ! terraform plan -var-file=terraform.tfvars -out=tfplan >> "$LOG_FILE" 2>&1; then
        print_error "  Planning failed for $layer"
        return 1
    fi
    
    # Apply
    print_info "  Applying changes..."
    if ! terraform apply tfplan >> "$LOG_FILE" 2>&1; then
        print_error "  Apply failed for $layer"
        return 1
    fi
    
    # Clean up plan file
    rm -f tfplan
    
    print_success "  Layer $layer deployed successfully"
    
    cd "$SCRIPT_DIR"
    return 0
}

# Deploy all layers
DEPLOYED_LAYERS=0
FAILED_LAYERS=0

for layer in "${LAYERS[@]}"; do
    echo ""
    if deploy_layer "$layer"; then
        ((DEPLOYED_LAYERS++))
    else
        ((FAILED_LAYERS++))
        print_error "Deployment failed for layer: $layer"
        print_info "Check logs at: $LOG_FILE"
        
        # Ask if user wants to continue
        echo -n "Continue with remaining layers? (y/n): "
        read -r continue_deploy
        if [[ ! "$continue_deploy" =~ ^[Yy]$ ]]; then
            print_error "Deployment stopped by user"
            exit 1
        fi
    fi
done

# Summary
print_header "Deployment Summary"
print_info "Environment: $ENVIRONMENT"
print_info "Total layers: ${#LAYERS[@]}"
print_success "Successfully deployed: $DEPLOYED_LAYERS"
if [ $FAILED_LAYERS -gt 0 ]; then
    print_error "Failed: $FAILED_LAYERS"
fi
print_info "Log file: $LOG_FILE"

if [ $FAILED_LAYERS -eq 0 ]; then
    echo ""
    print_success "🎉 All layers deployed successfully!"
    echo ""
    print_info "Next steps:"
    echo "  1. Verify resources in AWS Console"
    echo "  2. Run validation script: ./scripts/validate.sh $ENVIRONMENT"
    echo "  3. Set up monitoring dashboards"
    echo "  4. Configure DNS records"
else
    echo ""
    print_error "Some layers failed to deploy. Please check the logs."
    exit 1
fi

# Generate outputs
print_info "Generating deployment outputs..."
OUTPUTS_DIR="$SCRIPT_DIR/outputs"
mkdir -p "$OUTPUTS_DIR"

for layer in "${LAYERS[@]}"; do
    layer_dir="$SCRIPT_DIR/layers/${layer}/environments/${ENVIRONMENT}"
    if [ -d "$layer_dir" ]; then
        cd "$layer_dir"
        terraform output -json > "$OUTPUTS_DIR/${ENVIRONMENT}-${layer}-outputs.json" 2>/dev/null || true
    fi
done

cd "$SCRIPT_DIR"

print_success "Deployment outputs saved to: $OUTPUTS_DIR"
echo ""
