#!/bin/bash
################################################################################
# Terraform Drift Detection Script
# Description: Detect infrastructure drift locally
# Usage: ./scripts/drift-detection.sh [layer] [environment]
# Examples:
#   ./scripts/drift-detection.sh                    # Check all
#   ./scripts/drift-detection.sh all all            # Check all
#   ./scripts/drift-detection.sh security prod      # Specific layer/env
#   ./scripts/drift-detection.sh all prod           # All layers in prod
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
LAYER=${1:-all}
ENVIRONMENT=${2:-all}
DRIFT_FOUND=0
ERRORS_FOUND=0
LAYERS_CHECKED=0
DRIFT_COUNT=0

# All layers
LAYERS=("security" "networking" "storage" "database" "monitoring" "compute")
ENVIRONMENTS=("dev" "qa" "uat" "prod")

# Create reports directory
REPORTS_DIR="drift-reports"
mkdir -p "$REPORTS_DIR"

################################################################################
# Functions
################################################################################

print_header() {
  echo ""
  echo "╔═══════════════════════════════════════════════════════════════╗"
  echo "║                                                                ║"
  echo "║           Terraform Drift Detection                            ║"
  echo "║                                                                ║"
  echo "╚═══════════════════════════════════════════════════════════════╝"
  echo ""
}

check_drift() {
  local layer=$1
  local env=$2
  local layer_path="layers/${layer}/environments/${env}"
  
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Checking: ${layer}/${env}${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
  
  # Check if directory exists
  if [ ! -d "$layer_path" ]; then
    echo -e "${YELLOW}⚠ Skipped${NC}: Directory not found"
    return 0
  fi
  
  LAYERS_CHECKED=$((LAYERS_CHECKED + 1))
  
  # Navigate to layer directory
  cd "$layer_path" || {
    echo -e "${RED}✗ Error${NC}: Cannot access directory"
    ERRORS_FOUND=$((ERRORS_FOUND + 1))
    cd - > /dev/null
    return 1
  }
  
  # Initialize if needed
  if [ ! -d ".terraform" ]; then
    echo "  Initializing Terraform..."
    if ! terraform init -backend-config=backend.conf -upgrade > /dev/null 2>&1; then
      echo -e "${RED}  ✗ Failed${NC}: Terraform init failed"
      ERRORS_FOUND=$((ERRORS_FOUND + 1))
      cd - > /dev/null
      return 1
    fi
  fi
  
  # Run terraform plan
  echo "  Running terraform plan..."
  set +e
  terraform plan -detailed-exitcode -no-color -out=tfplan > plan-output.txt 2>&1
  EXIT_CODE=$?
  set -e
  
  case $EXIT_CODE in
    0)
      echo -e "${GREEN}  ✓ No Drift${NC}: Infrastructure matches Terraform state"
      ;;
    
    1)
      echo -e "${RED}  ✗ Error${NC}: Terraform plan failed"
      echo ""
      echo "  Error Details:"
      echo "  ─────────────────────────────────────────────────────────────"
      cat plan-output.txt | head -30
      echo "  ─────────────────────────────────────────────────────────────"
      ERRORS_FOUND=$((ERRORS_FOUND + 1))
      ;;
    
    2)
      echo -e "${YELLOW}  ⚠ Drift Detected${NC}: Changes found!"
      DRIFT_FOUND=$((DRIFT_FOUND + 1))
      DRIFT_COUNT=$((DRIFT_COUNT + 1))
      
      # Extract summary
      echo ""
      echo "  Drift Summary:"
      echo "  ─────────────────────────────────────────────────────────────"
      grep -A 2 "Terraform will perform" plan-output.txt || echo "  See plan output for details"
      echo "  ─────────────────────────────────────────────────────────────"
      echo ""
      
      # Show changed resources
      echo "  Changed Resources:"
      echo "  ─────────────────────────────────────────────────────────────"
      grep "^  [~+-]" plan-output.txt | head -20 || echo "  See full plan for details"
      echo "  ─────────────────────────────────────────────────────────────"
      
      # Save drift report
      TIMESTAMP=$(date +%Y%m%d-%H%M%S)
      REPORT_FILE="${REPORTS_DIR}/${layer}-${env}-${TIMESTAMP}.txt"
      cp plan-output.txt "../../../../${REPORT_FILE}"
      echo ""
      echo -e "${YELLOW}  📄 Drift report saved: ${REPORT_FILE}${NC}"
      ;;
  esac
  
  # Cleanup
  rm -f plan-output.txt tfplan
  cd - > /dev/null
  
  return 0
}

################################################################################
# Main
################################################################################

print_header

# Validate inputs
if [ "$LAYER" != "all" ] && [[ ! " ${LAYERS[@]} " =~ " ${LAYER} " ]]; then
  echo -e "${RED}Error:${NC} Invalid layer: $LAYER"
  echo "Valid layers: ${LAYERS[@]} or 'all'"
  exit 1
fi

if [ "$ENVIRONMENT" != "all" ] && [[ ! " ${ENVIRONMENTS[@]} " =~ " ${ENVIRONMENT} " ]]; then
  echo -e "${RED}Error:${NC} Invalid environment: $ENVIRONMENT"
  echo "Valid environments: ${ENVIRONMENTS[@]} or 'all'"
  exit 1
fi

# Determine scope
if [ "$LAYER" == "all" ]; then
  CHECK_LAYERS=("${LAYERS[@]}")
else
  CHECK_LAYERS=("$LAYER")
fi

if [ "$ENVIRONMENT" == "all" ]; then
  CHECK_ENVIRONMENTS=("${ENVIRONMENTS[@]}")
else
  CHECK_ENVIRONMENTS=("$ENVIRONMENT")
fi

echo "Drift Detection Scope:"
echo "  Layers:       ${CHECK_LAYERS[@]}"
echo "  Environments: ${CHECK_ENVIRONMENTS[@]}"
echo "  Total Checks: $((${#CHECK_LAYERS[@]} * ${#CHECK_ENVIRONMENTS[@]}))"
echo ""

# Run drift detection
START_TIME=$(date +%s)

for layer in "${CHECK_LAYERS[@]}"; do
  for env in "${CHECK_ENVIRONMENTS[@]}"; do
    check_drift "$layer" "$env"
  done
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Summary
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                      DRIFT DETECTION SUMMARY                   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Layers Checked:    $LAYERS_CHECKED"
echo "  Drift Detected:    $DRIFT_COUNT"
echo "  Errors:            $ERRORS_FOUND"
echo "  Duration:          ${DURATION}s"
echo ""

if [ $DRIFT_FOUND -eq 0 ] && [ $ERRORS_FOUND -eq 0 ]; then
  echo -e "${GREEN}✓ SUCCESS${NC}: No drift detected. All infrastructure matches Terraform state."
  echo ""
  exit 0
elif [ $ERRORS_FOUND -gt 0 ]; then
  echo -e "${RED}✗ ERRORS${NC}: $ERRORS_FOUND error(s) occurred during drift detection."
  echo ""
  echo "Review the error output above and fix any Terraform configuration issues."
  echo ""
  exit 1
else
  echo -e "${YELLOW}⚠ DRIFT DETECTED${NC}: $DRIFT_COUNT layer(s) have infrastructure drift."
  echo ""
  echo "Next Steps:"
  echo "  1. Review drift reports in: $REPORTS_DIR/"
  echo "  2. Investigate what changed (check CloudTrail)"
  echo "  3. Decide: Update Terraform OR revert AWS changes"
  echo "  4. Document resolution in: $REPORTS_DIR/CHANGELOG.md"
  echo "  5. Run drift detection again to verify"
  echo ""
  echo "Quick fixes:"
  echo "  • Update Terraform: Edit .tf/.tfvars, commit, push"
  echo "  • Revert AWS:       cd layers/LAYER/environments/ENV && terraform apply"
  echo ""
  exit 2
fi
