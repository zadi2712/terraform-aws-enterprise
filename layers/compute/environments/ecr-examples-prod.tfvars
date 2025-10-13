# ECR Repositories Configuration Example for Production Environment
# Add these to your layers/compute/environments/prod/terraform.tfvars file

################################################################################
# ECR Repositories - Production Configuration
################################################################################

ecr_repositories = {
  # Web application - Production
  "web-app" = {
    image_tag_mutability     = "IMMUTABLE"        # Immutable tags for prod
    scan_on_push             = true
    enable_enhanced_scanning = true               # Enhanced scanning for prod
    scan_frequency           = "CONTINUOUS_SCAN"  # Continuous monitoring
    max_image_count          = 100                # Keep more images in prod
    enable_lambda_pull       = false
    enable_cross_account_access = true            # Allow UAT/QA access
    allowed_account_ids      = [
      "123456789012",  # UAT account
      "210987654321"   # QA account
    ]
    enable_replication       = true               # Multi-region for DR
    replication_destinations = [
      {
        region      = "us-west-2"
        registry_id = "YOUR_AWS_ACCOUNT_ID"
      },
      {
        region      = "eu-west-1"
        registry_id = "YOUR_AWS_ACCOUNT_ID"
      }
    ]
  }

  # API service - Production
  "api-service" = {
    image_tag_mutability     = "IMMUTABLE"
    scan_on_push             = true
    enable_enhanced_scanning = true
    scan_frequency           = "CONTINUOUS_SCAN"
    max_image_count          = 100
    enable_cross_account_access = true
    allowed_account_ids      = ["123456789012", "210987654321"]
    enable_replication       = true
    replication_destinations = [
      {
        region      = "us-west-2"
        registry_id = "YOUR_AWS_ACCOUNT_ID"
      }
    ]
  }

  # Background worker - Production
  "worker" = {
    image_tag_mutability     = "IMMUTABLE"
    scan_on_push             = true
    enable_enhanced_scanning = true
    max_image_count          = 50
    enable_cross_account_access = true
    allowed_account_ids      = ["123456789012"]
  }

  # Lambda function - Production
  "lambda-processor" = {
    image_tag_mutability     = "IMMUTABLE"
    scan_on_push             = true
    enable_enhanced_scanning = true
    max_image_count          = 30
    enable_lambda_pull       = true
    enable_replication       = true
    replication_destinations = [
      {
        region      = "us-west-2"
        registry_id = "YOUR_AWS_ACCOUNT_ID"
      }
    ]
  }

  # Shared base images
  "base-images" = {
    image_tag_mutability     = "IMMUTABLE"
    scan_on_push             = true
    enable_enhanced_scanning = true
    max_image_count          = 20
    enable_cross_account_access = true
    allowed_account_ids      = [
      "123456789012",  # UAT
      "210987654321",  # QA
      "345678901234"   # Dev
    ]
  }
}

# ECR encryption with KMS for production
ecr_encryption_type = "KMS"

# Scan findings logging enabled for compliance
ecr_enable_scan_findings_logging = true
ecr_log_retention_days           = 90  # 90 days for compliance
