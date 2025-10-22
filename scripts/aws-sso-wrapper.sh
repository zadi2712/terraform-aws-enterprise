#!/bin/bash
# ~/.local/bin/aws-sso-wrapper.sh

AWS_PROFILE="${AWS_PROFILE:-default}"

# Function to check if token is expired
token_expired() {
    aws sts get-caller-identity --profile "$AWS_PROFILE" &>/dev/null
    return $?
}

# Function to refresh SSO token
refresh_token() {
    echo "AWS SSO token expired. Refreshing..."
    aws sso login --profile "$AWS_PROFILE"
}

# Check and refresh if needed
if ! token_expired; then
    refresh_token
fi

# Execute the command
"$@"