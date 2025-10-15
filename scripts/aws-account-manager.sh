#!/bin/bash

# AWS Account Manager Script
# Manages AWS accounts creation and switching for enterprise environments
# Author: DevOps Team
# Version: 1.0

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/config/aws-accounts.conf"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}
error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Help function
show_help() {
    cat << EOF
AWS Account Manager - Enterprise Edition

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    create-account      Create a new AWS account in organization
    switch              Switch to a specific AWS account/profile
    list-accounts       List all available AWS accounts
    list-profiles       List all configured AWS profiles
    setup-profile       Setup a new AWS profile
    assume-role         Assume a role in target account
    terraform-init      Initialize Terraform for specific account
    terraform-switch    Switch Terraform workspace for account
    export-env          Export environment variables for account
    validate            Validate current AWS configuration

Options:
    -a, --account-name    Account name (required for create-account)
    -e, --email          Email for new account (required for create-account)
    -p, --profile        AWS profile name
    -r, --role           IAM role ARN to assume
    -w, --workspace      Terraform workspace name
    -o, --output         Output format (json, table, text)
    -h, --help           Show this help message

Examples:
    # Create a new AWS account
    $0 create-account --account-name "prod-us-east-1" --email "aws-prod@company.com"
    
    # Switch to a specific profile
    $0 switch --profile "dev-profile"
    
    # List all accounts
    $0 list-accounts
    
    # Setup a new profile with assume role
    $0 setup-profile --profile "prod" --role "arn:aws:iam::123456789012:role/OrganizationAccountAccessRole"
    
    # Switch Terraform workspace
    $0 terraform-switch --workspace "prod-us-east-1"

EOF
}

# Create config directory if it doesn't exist
create_config_dir() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# AWS Accounts Configuration
# Format: ACCOUNT_NAME|ACCOUNT_ID|PROFILE_NAME|ROLE_ARN|DESCRIPTION
# Example: prod-us-east-1|123456789012|prod-profile|arn:aws:iam::123456789012:role/OrganizationAccountAccessRole|Production US East 1

EOF
    fi
}

# Validate AWS CLI installation
validate_aws_cli() {
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install it first."
    fi
}

# Validate Terraform installation
validate_terraform() {
    if ! command -v terraform &> /dev/null; then
        warn "Terraform is not installed. Terraform commands will not work."
        return 1
    fi
    return 0
}

# Create new AWS account in organization
create_account() {
    local account_name="$1"
    local email="$2"
    
    log "Creating new AWS account: $account_name"
    
    # Check if we're in an organization
    if ! aws organizations describe-organization &> /dev/null; then
        error "Not in an AWS Organization or insufficient permissions"
    fi
    
    # Create the account
    local create_result
    create_result=$(aws organizations create-account \
        --account-name "$account_name" \
        --email "$email" \
        --output json)
    
    local request_id
    request_id=$(echo "$create_result" | jq -r '.CreateAccountStatus.Id')
    
    info "Account creation initiated. Request ID: $request_id"
    info "Waiting for account creation to complete..."
    
    # Wait for account creation to complete
    while true; do
        local status_result
        status_result=$(aws organizations describe-create-account-status \
            --create-account-request-id "$request_id" \
            --output json)
        
        local status
        status=$(echo "$status_result" | jq -r '.CreateAccountStatus.State')
        
        case "$status" in
            "SUCCEEDED")
                local account_id
                account_id=$(echo "$status_result" | jq -r '.CreateAccountStatus.AccountId')
                log "Account created successfully!"
                info "Account ID: $account_id"
                info "Account Name: $account_name"
                
                # Add to config file
                echo "$account_name|$account_id|${account_name}-profile|arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole|Created $(date)" >> "$CONFIG_FILE"
                
                return 0
                ;;
            "FAILED")
                local failure_reason
                failure_reason=$(echo "$status_result" | jq -r '.CreateAccountStatus.FailureReason')
                error "Account creation failed: $failure_reason"
                ;;
            "IN_PROGRESS")
                echo -n "."
                sleep 10
                ;;
        esac
    done
}

# List all AWS accounts in organization
list_accounts() {
    local output_format="${1:-table}"
    
    log "Listing AWS accounts in organization..."
    
    case "$output_format" in
        "json")
            aws organizations list-accounts --output json
            ;;
        "table")
            aws organizations list-accounts --output table
            ;;
        *)
            aws organizations list-accounts --query 'Accounts[*].[Id,Name,Email,Status]' --output text | \
                while IFS=$'\t' read -r id name email status; do
                    printf "%-12s %-30s %-40s %s\n" "$id" "$name" "$email" "$status"
                done
            ;;
    esac
}

# List configured AWS profiles
list_profiles() {
    log "Listing configured AWS profiles..."
    
    if [[ -f ~/.aws/config ]]; then
        grep -E '^\[profile ' ~/.aws/config | sed 's/\[profile \(.*\)\]/\1/' | sort
    else
        warn "No AWS config file found"
    fi
    
    echo
    info "Default profile:"
    aws configure list
}

# Setup a new AWS profile
setup_profile() {
    local profile_name="$1"
    local role_arn="${2:-}"
    
    log "Setting up AWS profile: $profile_name"
    
    if [[ -n "$role_arn" ]]; then
        # Setup profile with assume role
        aws configure set profile."$profile_name".role_arn "$role_arn"
        aws configure set profile."$profile_name".source_profile default
        aws configure set profile."$profile_name".region us-east-1
        info "Profile $profile_name configured with assume role: $role_arn"
    else
        # Interactive setup
        aws configure --profile "$profile_name"
    fi
}

# Switch to a specific AWS profile
switch_profile() {
    local profile_name="$1"
    
    log "Switching to AWS profile: $profile_name"
    
    # Validate profile exists
    if ! aws configure list-profiles | grep -q "^$profile_name$"; then
        error "Profile '$profile_name' not found"
    fi
    
    # Export AWS_PROFILE
    export AWS_PROFILE="$profile_name"
    
    # Create/update environment file
    cat > "$PROJECT_ROOT/.aws-env" << EOF
export AWS_PROFILE="$profile_name"
export AWS_DEFAULT_PROFILE="$profile_name"
EOF
    
    log "Switched to profile: $profile_name"
    
    # Show current profile info
    info "Current AWS identity:"
    aws sts get-caller-identity
}

# Assume role in target account
assume_role() {
    local role_arn="$1"
    local session_name="${2:-aws-account-manager-session}"
    
    log "Assuming role: $role_arn"
    
    local assume_result
    assume_result=$(aws sts assume-role \
        --role-arn "$role_arn" \
        --role-session-name "$session_name" \
        --output json)
    
    local access_key_id secret_access_key session_token
    access_key_id=$(echo "$assume_result" | jq -r '.Credentials.AccessKeyId')
    secret_access_key=$(echo "$assume_result" | jq -r '.Credentials.SecretAccessKey')
    session_token=$(echo "$assume_result" | jq -r '.Credentials.SessionToken')
    
    # Export temporary credentials
    export AWS_ACCESS_KEY_ID="$access_key_id"
    export AWS_SECRET_ACCESS_KEY="$secret_access_key"
    export AWS_SESSION_TOKEN="$session_token"
    
    # Create/update environment file
    cat > "$PROJECT_ROOT/.aws-env" << EOF
export AWS_ACCESS_KEY_ID="$access_key_id"
export AWS_SECRET_ACCESS_KEY="$secret_access_key"
export AWS_SESSION_TOKEN="$session_token"
EOF
    
    log "Successfully assumed role. Temporary credentials exported."
    
    # Show current identity
    info "Current AWS identity:"
    aws sts get-caller-identity
}

# Initialize Terraform for specific account
terraform_init() {
    local workspace="${1:-default}"
    
    if ! validate_terraform; then
        return 1
    fi
    
    log "Initializing Terraform for workspace: $workspace"
    
    cd "$TERRAFORM_DIR" || error "Terraform directory not found: $TERRAFORM_DIR"
    
    # Initialize Terraform
    terraform init
    
    # Create workspace if it doesn't exist
    if ! terraform workspace list | grep -q " $workspace$"; then
        terraform workspace new "$workspace"
    fi
    
    # Select workspace
    terraform workspace select "$workspace"
    
    log "Terraform initialized for workspace: $workspace"
}

# Switch Terraform workspace
terraform_switch() {
    local workspace="$1"
    
    if ! validate_terraform; then
        return 1
    fi
    
    log "Switching to Terraform workspace: $workspace"
    
    cd "$TERRAFORM_DIR" || error "Terraform directory not found: $TERRAFORM_DIR"
    
    # Create workspace if it doesn't exist
    if ! terraform workspace list | grep -q " $workspace$"; then
        warn "Workspace '$workspace' doesn't exist. Creating it..."
        terraform workspace new "$workspace"
    else
        terraform workspace select "$workspace"
    fi
    
    log "Switched to Terraform workspace: $workspace"
    terraform workspace show
}

# Export environment variables for account
export_env() {
    local profile_name="${1:-}"
    
    if [[ -n "$profile_name" ]]; then
        export AWS_PROFILE="$profile_name"
    fi
    
    log "Current AWS environment variables:"
    env | grep -E '^AWS_' | sort
    
    if [[ -f "$PROJECT_ROOT/.aws-env" ]]; then
        info "To load environment variables, run: source $PROJECT_ROOT/.aws-env"
    fi
}

# Validate current AWS configuration
validate_config() {
    log "Validating AWS configuration..."
    
    # Check AWS CLI
    validate_aws_cli
    
    # Check current identity
    if aws sts get-caller-identity &> /dev/null; then
        info "✓ AWS credentials are valid"
        aws sts get-caller-identity
    else
        warn "✗ AWS credentials are not configured or invalid"
    fi
    
    # Check profiles
    info "Available profiles:"
    aws configure list-profiles
    
    # Check organization status
    if aws organizations describe-organization &> /dev/null; then
        info "✓ Organization access available"
    else
        warn "✗ No organization access or not in an organization"
    fi
}

# Main function
main() {
    # Create config directory
    create_config_dir
    
    # Validate AWS CLI
    validate_aws_cli
    
    # Parse command line arguments
    local command="${1:-}"
    shift || true
    
    case "$command" in
        "create-account")
            local account_name="" email=""
            while [[ $# -gt 0 ]]; do
                case $1 in
                    -a|--account-name)
                        account_name="$2"
                        shift 2
                        ;;
                    -e|--email)
                        email="$2"
                        shift 2
                        ;;
                    *)
                        error "Unknown option: $1"
                        ;;
                esac
            done
            
            [[ -z "$account_name" ]] && error "Account name is required"
            [[ -z "$email" ]] && error "Email is required"
            
            create_account "$account_name" "$email"
            ;;
            
        "switch")
            local profile_name=""
            while [[ $# -gt 0 ]]; do
                case $1 in
                    -p|--profile)
                        profile_name="$2"
                        shift 2
                        ;;
                    *)
                        error "Unknown option: $1"
                        ;;
                esac
            done
            
            [[ -z "$profile_name" ]] && error "Profile name is required"
            switch_profile "$profile_name"
            ;;
            
        "list-accounts")
            local output_format="table"
            while [[ $# -gt 0 ]]; do
                case $1 in
                    -o|--output)
                        output_format="$2"
                        shift 2
                        ;;
                    *)
                        error "Unknown option: $1"
                        ;;
                esac
            done
            
            list_accounts "$output_format"
            ;;
            
        "list-profiles")
            list_profiles
            ;;
            
        "setup-profile")
            local profile_name="" role_arn=""
            while [[ $# -gt 0 ]]; do
                case $1 in
                    -p|--profile)
                        profile_name="$2"
                        shift 2
                        ;;
                    -r|--role)
                        role_arn="$2"
                        shift 2
                        ;;
                    *)
                        error "Unknown option: $1"
                        ;;
                esac
            done
            
            [[ -z "$profile_name" ]] && error "Profile name is required"
            setup_profile "$profile_name" "$role_arn"
            ;;
            
        "assume-role")
            local role_arn=""
            while [[ $# -gt 0 ]]; do
                case $1 in
                    -r|--role)
                        role_arn="$2"
                        shift 2
                        ;;
                    *)
                        error "Unknown option: $1"
                        ;;
                esac
            done
            
            [[ -z "$role_arn" ]] && error "Role ARN is required"
            assume_role "$role_arn"
            ;;
            
        "terraform-init")
            local workspace="default"
            while [[ $# -gt 0 ]]; do
                case $1 in
                    -w|--workspace)
                        workspace="$2"
                        shift 2
                        ;;
                    *)
                        error "Unknown option: $1"
                        ;;
                esac
            done
            
            terraform_init "$workspace"
            ;;
            
        "terraform-switch")
            local workspace=""
            while [[ $# -gt 0 ]]; do
                case $1 in
                    -w|--workspace)
                        workspace="$2"
                        shift 2
                        ;;
                    *)
                        error "Unknown option: $1"
                        ;;
                esac
            done
            
            [[ -z "$workspace" ]] && error "Workspace name is required"
            terraform_switch "$workspace"
            ;;
            
        "export-env")
            local profile_name=""
            while [[ $# -gt 0 ]]; do
                case $1 in
                    -p|--profile)
                        profile_name="$2"
                        shift 2
                        ;;
                    *)
                        error "Unknown option: $1"
                        ;;
                esac
            done
            
            export_env "$profile_name"
            ;;
            
        "validate")
            validate_config
            ;;
            
        "-h"|"--help"|"help"|"")
            show_help
            ;;
            
        *)
            error "Unknown command: $command. Use --help for usage information."
            ;;
    esac
}

# Run main function
main "$@"
