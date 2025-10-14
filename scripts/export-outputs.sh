#!/bin/bash

################################################################################
# Export Terraform Outputs Script
# 
# This script exports Terraform outputs from deployed layers to JSON files
# in the outputs/ directory for easy reference and automation.
#
# Usage:
#   ./scripts/export-outputs.sh [environment] [layer]
#   ./scripts/export-outputs.sh dev              # Export all layers for dev
#   ./scripts/export-outputs.sh prod networking  # Export networking layer for prod
#   ./scripts/export-outputs.sh all              # Export all environments and layers
################################################################################

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUTS_DIR="$REPO_ROOT/outputs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_error() {
    echo -e "${RED}❌ ERROR: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Available layers
LAYERS=(networking security dns storage database compute monitoring)

# Available environments
ENVIRONMENTS=(dev qa uat prod)

# Help message
show_help() {
    cat << EOF
Export Terraform Outputs Script

Usage:
  $0 [environment] [layer]
  $0 [environment]              # Export all layers for environment
  $0 all                        # Export all environments and layers

Arguments:
  environment    Target environment (dev, qa, uat, prod, all)
  layer         Specific layer to export (optional)
                Available: networking, security, dns, storage, database, compute, monitoring

Examples:
  $0 dev                    # Export all layers for dev environment
  $0 prod networking        # Export only networking layer for prod
  $0 all                    # Export all environments and layers

Options:
  -h, --help               Show this help message
  -v, --verbose            Verbose output
  --force                  Overwrite existing output files without confirmation

Output:
  Files saved to: $OUTPUTS_DIR/
  Format: {environment}-{layer}-outputs.json
  Example: dev-networking-outputs.json

EOF
}

# Parse arguments
VERBOSE=false
FORCE=false
ENVIRONMENT=""
LAYER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            if [ -z "$ENVIRONMENT" ]; then
                ENVIRONMENT=$1
            elif [ -z "$LAYER" ]; then
                LAYER=$1
            else
                print_error "Too many arguments"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate environment
if [ -z "$ENVIRONMENT" ]; then
    print_error "Environment is required"
    show_help
    exit 1
fi

# Export outputs for a specific layer and environment
export_layer_outputs() {
    local env=$1
    local layer=$2
    local layer_dir="$REPO_ROOT/layers/$layer"
    local env_dir="$layer_dir/environments/$env"
    local output_file="$OUTPUTS_DIR/${env}-${layer}-outputs.json"
    
    if [ ! -d "$env_dir" ]; then
        print_warning "Environment directory not found: $env_dir"
        return 1
    fi
    
    # Check if layer is deployed (has terraform state)
    if [ ! -d "$env_dir/.terraform" ]; then
        print_warning "Layer '$layer' not initialized for '$env' environment"
        return 1
    fi
    
    print_info "Exporting outputs: $env-$layer"
    
    # Change to environment directory
    cd "$env_dir"
    
    # Check if there are any outputs
    if ! terraform output -json > /dev/null 2>&1; then
        print_warning "No outputs available or Terraform state not found"
        return 1
    fi
    
    # Export outputs
    if terraform output -json > "$output_file" 2>/dev/null; then
        # Check if file has content
        if [ -s "$output_file" ]; then
            local num_outputs=$(jq 'length' "$output_file" 2>/dev/null || echo "0")
            print_success "Exported $num_outputs output(s) to: ${env}-${layer}-outputs.json"
            
            if [ "$VERBOSE" = true ]; then
                echo "  Output keys:"
                jq -r 'keys[]' "$output_file" 2>/dev/null | sed 's/^/    - /'
            fi
        else
            echo "{}" > "$output_file"
            print_warning "No outputs defined for this layer"
        fi
        return 0
    else
        print_error "Failed to export outputs for $layer"
        return 1
    fi
}

# Main execution
main() {
    print_header "Terraform Outputs Export"
    
    # Create outputs directory
    mkdir -p "$OUTPUTS_DIR"
    
    # Determine what to export
    local export_count=0
    local success_count=0
    local failed_count=0
    
    if [ "$ENVIRONMENT" = "all" ]; then
        # Export all environments and layers
        print_info "Exporting outputs for all environments and layers..."
        echo ""
        
        for env in "${ENVIRONMENTS[@]}"; do
            print_info "Environment: $env"
            for layer in "${LAYERS[@]}"; do
                export_count=$((export_count + 1))
                if export_layer_outputs "$env" "$layer"; then
                    success_count=$((success_count + 1))
                else
                    failed_count=$((failed_count + 1))
                fi
            done
            echo ""
        done
    elif [ -n "$LAYER" ]; then
        # Export specific layer for specific environment
        print_info "Exporting outputs for $LAYER layer in $ENVIRONMENT environment..."
        echo ""
        
        export_count=1
        if export_layer_outputs "$ENVIRONMENT" "$LAYER"; then
            success_count=1
        else
            failed_count=1
        fi
    else
        # Export all layers for specific environment
        print_info "Exporting outputs for all layers in $ENVIRONMENT environment..."
        echo ""
        
        for layer in "${LAYERS[@]}"; do
            export_count=$((export_count + 1))
            if export_layer_outputs "$ENVIRONMENT" "$layer"; then
                success_count=$((success_count + 1))
            else
                failed_count=$((failed_count + 1))
            fi
        done
    fi
    
    # Summary
    cd "$REPO_ROOT"
    echo ""
    print_header "Export Summary"
    echo "Total exports attempted: $export_count"
    print_success "Successful: $success_count"
    if [ $failed_count -gt 0 ]; then
        print_error "Failed: $failed_count"
    fi
    echo ""
    print_info "Outputs directory: $OUTPUTS_DIR"
    echo ""
    
    # List all output files
    if [ "$(ls -A "$OUTPUTS_DIR"/*.json 2>/dev/null)" ]; then
        print_info "Available output files:"
        ls -lh "$OUTPUTS_DIR"/*.json 2>/dev/null | awk '{print "  - " $9 " (" $5 ")"}'
    fi
    
    echo ""
    
    if [ $success_count -gt 0 ]; then
        print_success "✨ Export completed successfully!"
        echo ""
        print_info "Usage examples:"
        echo "  # View all outputs"
        echo "  cat $OUTPUTS_DIR/*.json"
        echo ""
        echo "  # Get specific value (requires jq)"
        echo "  jq -r '.vpc_id.value' $OUTPUTS_DIR/dev-networking-outputs.json"
        echo ""
        echo "  # List all keys in a file"
        echo "  jq 'keys' $OUTPUTS_DIR/dev-networking-outputs.json"
    else
        print_warning "No outputs were exported successfully"
        echo ""
        print_info "Possible reasons:"
        echo "  - Layers not yet deployed"
        echo "  - Terraform not initialized"
        echo "  - No outputs defined in layer"
    fi
}

# Run main function
main