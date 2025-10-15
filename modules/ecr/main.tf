################################################################################
# ECR Module - Elastic Container Registry
# Description: Creates and manages ECR repositories with security best practices
################################################################################

# ECR Repository
resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability

  # Encryption configuration
  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.kms_key_arn
  }

  # Image scanning configuration
  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  # Force delete even if contains images
  force_delete = var.force_delete

  tags = merge(
    var.tags,
    {
      Name = var.repository_name
    }
  )
}

################################################################################
# Lifecycle Policy
################################################################################

resource "aws_ecr_lifecycle_policy" "this" {
  count = var.lifecycle_policy != null ? 1 : 0

  repository = aws_ecr_repository.this.name

  policy = var.lifecycle_policy != null ? var.lifecycle_policy : jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.max_image_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.max_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

################################################################################
# Repository Policy
################################################################################

resource "aws_ecr_repository_policy" "this" {
  count = var.repository_policy != null || var.enable_cross_account_access ? 1 : 0

  repository = aws_ecr_repository.this.name

  policy = var.repository_policy != null ? var.repository_policy : jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      var.enable_cross_account_access ? [
        {
          Sid    = "CrossAccountPull"
          Effect = "Allow"
          Principal = {
            AWS = var.allowed_account_ids
          }
          Action = [
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "ecr:BatchCheckLayerAvailability"
          ]
        }
      ] : [],
      var.enable_lambda_pull ? [
        {
          Sid    = "LambdaECRImageRetrievalPolicy"
          Effect = "Allow"
          Principal = {
            Service = "lambda.amazonaws.com"
          }
          Action = [
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage"
          ]
        }
      ] : []
    )
  })
}

################################################################################
# Replication Configuration
################################################################################

resource "aws_ecr_replication_configuration" "this" {
  count = var.enable_replication && length(var.replication_destinations) > 0 ? 1 : 0

  replication_configuration {
    rule {
      dynamic "destination" {
        for_each = var.replication_destinations

        content {
          region      = destination.value.region
          registry_id = destination.value.registry_id
        }
      }

      repository_filter {
        filter      = var.repository_name
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}

################################################################################
# Registry Scanning Configuration
################################################################################

resource "aws_ecr_registry_scanning_configuration" "this" {
  count = var.enable_enhanced_scanning ? 1 : 0

  scan_type = "ENHANCED"

  rule {
    scan_frequency = var.scan_frequency

    repository_filter {
      filter      = var.repository_name
      filter_type = "WILDCARD"
    }
  }
}

################################################################################
# Pull Through Cache Rule (for public registries like Docker Hub)
################################################################################

resource "aws_ecr_pull_through_cache_rule" "this" {
  count = var.enable_pull_through_cache ? 1 : 0

  ecr_repository_prefix = var.pull_through_cache_prefix
  upstream_registry_url = var.upstream_registry_url

  credential_arn = var.pull_through_cache_credential_arn
}

################################################################################
# Registry Policy (Account-level)
################################################################################

resource "aws_ecr_registry_policy" "this" {
  count = var.registry_policy != null ? 1 : 0

  policy = var.registry_policy
}

################################################################################
# CloudWatch Log Group for Image Scan Findings
################################################################################

resource "aws_cloudwatch_log_group" "scan_findings" {
  count = var.enable_scan_findings_logging ? 1 : 0

  name              = "/aws/ecr/${var.repository_name}/scan-findings"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(
    var.tags,
    {
      Name = "${var.repository_name}-scan-findings"
    }
  )
}

################################################################################
# SSM Parameter Store - Store ECR Repository Information
################################################################################

# Store repository URL
resource "aws_ssm_parameter" "repository_url" {
  name        = "/ecr/${var.repository_name}/url"
  description = "ECR repository URL for ${var.repository_name}"
  type        = "String"
  value       = aws_ecr_repository.this.repository_url

  tags = merge(
    var.tags,
    {
      Name       = "${var.repository_name}-url"
      Repository = var.repository_name
      Type       = "ecr-url"
    }
  )
}

# Store repository ARN
resource "aws_ssm_parameter" "repository_arn" {
  name        = "/ecr/${var.repository_name}/arn"
  description = "ECR repository ARN for ${var.repository_name}"
  type        = "String"
  value       = aws_ecr_repository.this.arn

  tags = merge(
    var.tags,
    {
      Name       = "${var.repository_name}-arn"
      Repository = var.repository_name
      Type       = "ecr-arn"
    }
  )
}

# Store repository name
resource "aws_ssm_parameter" "repository_name" {
  name        = "/ecr/${var.repository_name}/name"
  description = "ECR repository name for ${var.repository_name}"
  type        = "String"
  value       = aws_ecr_repository.this.name

  tags = merge(
    var.tags,
    {
      Name       = "${var.repository_name}-name"
      Repository = var.repository_name
      Type       = "ecr-name"
    }
  )
}

# Store registry ID
resource "aws_ssm_parameter" "registry_id" {
  name        = "/ecr/${var.repository_name}/registry-id"
  description = "ECR registry ID for ${var.repository_name}"
  type        = "String"
  value       = aws_ecr_repository.this.registry_id

  tags = merge(
    var.tags,
    {
      Name       = "${var.repository_name}-registry-id"
      Repository = var.repository_name
      Type       = "ecr-registry-id"
    }
  )
}

# Store scanning configuration
resource "aws_ssm_parameter" "scan_on_push" {
  name        = "/ecr/${var.repository_name}/scan-on-push"
  description = "Scan on push configuration for ${var.repository_name}"
  type        = "String"
  value       = tostring(var.scan_on_push)

  tags = merge(
    var.tags,
    {
      Name       = "${var.repository_name}-scan-config"
      Repository = var.repository_name
      Type       = "ecr-config"
    }
  )
}

# Store encryption type
resource "aws_ssm_parameter" "encryption_type" {
  name        = "/ecr/${var.repository_name}/encryption-type"
  description = "Encryption type for ${var.repository_name}"
  type        = "String"
  value       = var.encryption_type

  tags = merge(
    var.tags,
    {
      Name       = "${var.repository_name}-encryption"
      Repository = var.repository_name
      Type       = "ecr-config"
    }
  )
}

# Store image tag mutability
resource "aws_ssm_parameter" "image_tag_mutability" {
  name        = "/ecr/${var.repository_name}/tag-mutability"
  description = "Image tag mutability for ${var.repository_name}"
  type        = "String"
  value       = var.image_tag_mutability

  tags = merge(
    var.tags,
    {
      Name       = "${var.repository_name}-tag-mutability"
      Repository = var.repository_name
      Type       = "ecr-config"
    }
  )
}
