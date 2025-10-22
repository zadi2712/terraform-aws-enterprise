# Auto-refresh AWS SSO credentials
aws() {
    # Check if credentials are expired
    if ! command aws sts get-caller-identity &>/dev/null; then
        if [[ -n "$AWS_PROFILE" ]]; then
            echo "🔑 AWS SSO credentials expired. Refreshing..."
            command aws sso login --profile "$AWS_PROFILE"
        fi
    fi
    
    # Run the actual AWS command
    command aws "$@"
}

terraform() {
    # Check if credentials are expired before terraform operations
    if ! command aws sts get-caller-identity &>/dev/null; then
        if [[ -n "$AWS_PROFILE" ]]; then
            echo "🔑 AWS SSO credentials expired. Refreshing for Terraform..."
            command aws sso login --profile "$AWS_PROFILE"
        fi
    fi
    
    # Run the actual Terraform command
    command terraform "$@"
}