#!/bin/bash
################################################################################
# Infrastructure Destruction Script
# Description: Safely destroy all resources in specified environment
# Usage: ./destroy.sh <environment>
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVIRONMENT=${1:-dev}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|qa|uat|prod)$ ]]; then
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    exit 1
fi

# Destruction order (reverse of deployment)
LAYERS=(
    "monitoring"
    "compute"
    "storage"
    "database"
    "dns"
    "security"
    "networking"
)

# Multiple confirmations for production
if [ "$ENVIRONMENT" == "prod" ]; then
    echo -e "${RED}⚠️  WARNING: You are about to DESTROY PRODUCTION infrastructure!${NC}"
    echo ""
    echo "This will DELETE ALL RESOURCES including:"
    echo "  - All EC2 instances and ECS tasks"
    echo "  - All databases (RDS instances)"
    echo "  - All S3 buckets and data"
    echo "  - All networking (VPC, subnets, etc.)"
    echo ""
    echo -e "${RED}THIS ACTION CANNOT BE UNDONE!${NC}"
    echo ""
    echo -n "Type 'DELETE-PRODUCTION' to continue: "
    read -r confirmation1
    
    if [ "$confirmation1" != "DELETE-PRODUCTION" ]; then
        echo "Destruction cancelled"
        exit 1
    fi
    
    echo ""
    echo -n "Are you ABSOLUTELY sure? Type 'YES-DELETE-EVERYTHING': "
    read -r confirmation2
    
    if [ "$confirmation2" != "YES-DELETE-EVERYTHING" ]; then
        echo "Destruction cancelled"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  You are about to destroy $ENVIRONMENT infrastructure${NC}"
    echo ""
    echo -n "Type 'DESTROY' to continue: "
    read -r confirmation
    
    if [ "$confirmation" != "DESTROY" ]; then
        echo "Destruction cancelled"
        exit 1
    fi
fi

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Destroying Infrastructure - $ENVIRONMENT${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Create log
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/destroy-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).log"

# Function to destroy a layer
destroy_layer() {
    local layer=$1
    local layer_dir="$SCRIPT_DIR/layers/${layer}/environments/${ENVIRONMENT}"
    
    echo -e "${BLUE}🗑️  Destroying layer: $layer${NC}"
    
    if [ ! -d "$layer_dir" ]; then
        echo -e "${YELLOW}⚠️  Layer directory not found: $layer_dir${NC}"
        return 0
    fi
    
    cd "$layer_dir"
    
    # Initialize if needed
    if [ ! -d ".terraform" ]; then
        terraform init -backend-config=backend.conf >> "$LOG_FILE" 2>&1 || true
    fi
    
    # Destroy
    if terraform destroy -var-file=terraform.tfvars -auto-approve >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}✅ Layer $layer destroyed${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to destroy layer: $layer${NC}"
        return 1
    fi
}

# Destroy all layers
DESTROYED=0
FAILED=0

for layer in "${LAYERS[@]}"; do
    if destroy_layer "$layer"; then
        ((DESTROYED++))
    else
        ((FAILED++))
        echo -e "${RED}Failed to destroy: $layer${NC}"
        echo -n "Continue? (y/n): "
        read -r continue
        if [[ ! "$continue" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    echo ""
done

cd "$SCRIPT_DIR"

# Summary
echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Destruction Summary${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""
echo -e "${GREEN}Destroyed: $DESTROYED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED${NC}"
fi
echo -e "${BLUE}Log: $LOG_FILE${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All resources destroyed successfully${NC}"
else
    echo -e "${RED}Some resources failed to destroy. Check logs.${NC}"
    exit 1
fi
