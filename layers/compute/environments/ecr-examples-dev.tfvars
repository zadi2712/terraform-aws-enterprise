# ECR Repositories Configuration Example for Development Environment
# Add these to your layers/compute/environments/dev/terraform.tfvars file

################################################################################
# ECR Repositories
################################################################################

# Define ECR repositories for your applications
ecr_repositories = {
  # Web application
  "web-app" = {
    image_tag_mutability        = "MUTABLE"      # Allow tag updates in dev
    scan_on_push                = true           # Scan every push
    enable_enhanced_scanning    = false          # Basic scanning for dev
    scan_frequency              = "SCAN_ON_PUSH" # Scan when pushed
    max_image_count             = 50             # Keep last 50 images
    enable_lambda_pull          = false          # Not a Lambda container
    enable_cross_account_access = false          # No cross-account in dev
    allowed_account_ids         = []
    enable_replication          = false # No replication in dev
    replication_destinations    = []
  }

  # API service
  "api-service" = {
    image_tag_mutability     = "MUTABLE"
    scan_on_push             = true
    enable_enhanced_scanning = false
    max_image_count          = 30
    enable_lambda_pull       = false
  }

  # Background worker
  "worker" = {
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    max_image_count      = 20
  }

  # Lambda function (if using container-based Lambda)
  "lambda-processor" = {
    image_tag_mutability = "MUTABLE"
    scan_on_push         = true
    max_image_count      = 10
    enable_lambda_pull   = true # Enable Lambda access
  }
}

# ECR encryption (use AES256 for dev, KMS for prod)
ecr_encryption_type = "AES256"

# Scan findings logging
ecr_enable_scan_findings_logging = false # Disable in dev to save costs
ecr_log_retention_days           = 7     # Short retention for dev
