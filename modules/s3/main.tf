################################################################################
# S3 Module - Enterprise Object Storage
# Version: 2.0
# Description: S3 buckets with encryption, versioning, replication, and policies
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  common_tags = merge(
    var.tags,
    {
      Module    = "s3"
      ManagedBy = "terraform"
    }
  )
}

################################################################################
# S3 Bucket
################################################################################

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(
    local.common_tags,
    {
      Name = var.bucket_name
    }
  )
}

################################################################################
# Bucket Versioning
################################################################################

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status     = var.versioning_enabled ? "Enabled" : "Suspended"
    mfa_delete = var.mfa_delete_enabled ? "Enabled" : "Disabled"
  }
}

################################################################################
# Server-Side Encryption
################################################################################

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = var.bucket_key_enabled
  }
}

################################################################################
# Public Access Block
################################################################################

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = var.block_public_access
  block_public_policy     = var.block_public_access
  ignore_public_acls      = var.block_public_access
  restrict_public_buckets = var.block_public_access
}

################################################################################
# Bucket Policy
################################################################################

resource "aws_s3_bucket_policy" "this" {
  count = var.bucket_policy != null || var.attach_deny_insecure_transport_policy ? 1 : 0

  bucket = aws_s3_bucket.this.id

  policy = var.bucket_policy != null ? var.bucket_policy : (
    var.attach_deny_insecure_transport_policy ? data.aws_iam_policy_document.deny_insecure_transport[0].json : null
  )

  depends_on = [aws_s3_bucket_public_access_block.this]
}

# Deny insecure transport (enforce HTTPS)
data "aws_iam_policy_document" "deny_insecure_transport" {
  count = var.attach_deny_insecure_transport_policy && var.bucket_policy == null ? 1 : 0

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

################################################################################
# Lifecycle Configuration
################################################################################

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = length(var.lifecycle_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules

    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      # Filter
      dynamic "filter" {
        for_each = lookup(rule.value, "filter", null) != null ? [rule.value.filter] : []

        content {
          prefix = lookup(filter.value, "prefix", null)

          dynamic "tag" {
            for_each = lookup(filter.value, "tags", {})

            content {
              key   = tag.key
              value = tag.value
            }
          }
        }
      }

      # Transitions
      dynamic "transition" {
        for_each = lookup(rule.value, "transitions", [])

        content {
          days          = lookup(transition.value, "days", null)
          date          = lookup(transition.value, "date", null)
          storage_class = transition.value.storage_class
        }
      }

      # Noncurrent version transitions
      dynamic "noncurrent_version_transition" {
        for_each = lookup(rule.value, "noncurrent_version_transitions", [])

        content {
          noncurrent_days = noncurrent_version_transition.value.noncurrent_days
          storage_class   = noncurrent_version_transition.value.storage_class
        }
      }

      # Expiration
      dynamic "expiration" {
        for_each = lookup(rule.value, "expiration", null) != null ? [rule.value.expiration] : []

        content {
          days                         = lookup(expiration.value, "days", null)
          date                         = lookup(expiration.value, "date", null)
          expired_object_delete_marker = lookup(expiration.value, "expired_object_delete_marker", null)
        }
      }

      # Noncurrent version expiration
      dynamic "noncurrent_version_expiration" {
        for_each = lookup(rule.value, "noncurrent_version_expiration", null) != null ? [rule.value.noncurrent_version_expiration] : []

        content {
          noncurrent_days = noncurrent_version_expiration.value.noncurrent_days
        }
      }

      # Abort incomplete multipart uploads
      dynamic "abort_incomplete_multipart_upload" {
        for_each = lookup(rule.value, "abort_incomplete_multipart_upload_days", null) != null ? [1] : []

        content {
          days_after_initiation = rule.value.abort_incomplete_multipart_upload_days
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

################################################################################
# Intelligent Tiering
################################################################################

resource "aws_s3_bucket_intelligent_tiering_configuration" "this" {
  for_each = var.intelligent_tiering_configurations

  bucket = aws_s3_bucket.this.id
  name   = each.key

  status = lookup(each.value, "status", "Enabled")

  dynamic "filter" {
    for_each = lookup(each.value, "filter", null) != null ? [each.value.filter] : []

    content {
      prefix = lookup(filter.value, "prefix", null)
      tags   = lookup(filter.value, "tags", {})
    }
  }

  dynamic "tiering" {
    for_each = each.value.tierings

    content {
      access_tier = tiering.value.access_tier
      days        = tiering.value.days
    }
  }
}

################################################################################
# CORS Configuration
################################################################################

resource "aws_s3_bucket_cors_configuration" "this" {
  count = length(var.cors_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.this.id

  dynamic "cors_rule" {
    for_each = var.cors_rules

    content {
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      allowed_headers = lookup(cors_rule.value, "allowed_headers", null)
      expose_headers  = lookup(cors_rule.value, "expose_headers", null)
      max_age_seconds = lookup(cors_rule.value, "max_age_seconds", null)
    }
  }
}

################################################################################
# Logging
################################################################################

resource "aws_s3_bucket_logging" "this" {
  count = var.logging_enabled ? 1 : 0

  bucket = aws_s3_bucket.this.id

  target_bucket = var.logging_target_bucket
  target_prefix = var.logging_target_prefix
}

################################################################################
# Replication
################################################################################

resource "aws_s3_bucket_replication_configuration" "this" {
  count = var.replication_enabled ? 1 : 0

  bucket = aws_s3_bucket.this.id
  role   = var.create_replication_role ? aws_iam_role.replication[0].arn : var.replication_role_arn

  dynamic "rule" {
    for_each = var.replication_rules

    content {
      id       = rule.key
      status   = lookup(rule.value, "status", "Enabled")
      priority = lookup(rule.value, "priority", null)

      dynamic "filter" {
        for_each = lookup(rule.value, "filter", null) != null ? [rule.value.filter] : []

        content {
          prefix = lookup(filter.value, "prefix", null)
        }
      }

      destination {
        bucket        = rule.value.destination_bucket
        storage_class = lookup(rule.value, "storage_class", "STANDARD")

        dynamic "encryption_configuration" {
          for_each = lookup(rule.value, "replica_kms_key_id", null) != null ? [1] : []

          content {
            replica_kms_key_id = rule.value.replica_kms_key_id
          }
        }

        dynamic "replication_time" {
          for_each = lookup(rule.value, "replication_time_enabled", false) ? [1] : []

          content {
            status = "Enabled"
            time {
              minutes = 15
            }
          }
        }

        dynamic "metrics" {
          for_each = lookup(rule.value, "metrics_enabled", false) ? [1] : []

          content {
            status = "Enabled"
            event_threshold {
              minutes = 15
            }
          }
        }
      }

      delete_marker_replication {
        status = lookup(rule.value, "delete_marker_replication", false) ? "Enabled" : "Disabled"
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

# IAM role for replication
resource "aws_iam_role" "replication" {
  count = var.create_replication_role && var.replication_enabled ? 1 : 0

  name = "${var.bucket_name}-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "replication" {
  count = var.create_replication_role && var.replication_enabled ? 1 : 0

  name = "replication-policy"
  role = aws_iam_role.replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.this.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.this.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = [for rule in var.replication_rules : "${rule.destination_bucket}/*"]
      }
    ]
  })
}

################################################################################
# Object Lock
################################################################################

resource "aws_s3_bucket_object_lock_configuration" "this" {
  count = var.object_lock_enabled ? 1 : 0

  bucket = aws_s3_bucket.this.id

  rule {
    default_retention {
      mode  = var.object_lock_mode
      days  = var.object_lock_days
      years = var.object_lock_years
    }
  }
}

################################################################################
# Notifications
################################################################################

resource "aws_s3_bucket_notification" "this" {
  count = var.enable_notifications ? 1 : 0

  bucket = aws_s3_bucket.this.id

  dynamic "lambda_function" {
    for_each = var.lambda_notifications

    content {
      lambda_function_arn = lambda_function.value.function_arn
      events              = lambda_function.value.events
      filter_prefix       = lookup(lambda_function.value, "filter_prefix", null)
      filter_suffix       = lookup(lambda_function.value, "filter_suffix", null)
    }
  }

  dynamic "queue" {
    for_each = var.sqs_notifications

    content {
      queue_arn     = queue.value.queue_arn
      events        = queue.value.events
      filter_prefix = lookup(queue.value, "filter_prefix", null)
      filter_suffix = lookup(queue.value, "filter_suffix", null)
    }
  }

  dynamic "topic" {
    for_each = var.sns_notifications

    content {
      topic_arn     = topic.value.topic_arn
      events        = topic.value.events
      filter_prefix = lookup(topic.value, "filter_prefix", null)
      filter_suffix = lookup(topic.value, "filter_suffix", null)
    }
  }
}

################################################################################
# Website Configuration
################################################################################

resource "aws_s3_bucket_website_configuration" "this" {
  count = var.website_enabled ? 1 : 0

  bucket = aws_s3_bucket.this.id

  index_document {
    suffix = var.website_index_document
  }

  dynamic "error_document" {
    for_each = var.website_error_document != null ? [1] : []

    content {
      key = var.website_error_document
    }
  }

  dynamic "routing_rule" {
    for_each = var.website_routing_rules

    content {
      condition {
        key_prefix_equals = lookup(routing_rule.value.condition, "key_prefix_equals", null)
        http_error_code_returned_equals = lookup(routing_rule.value.condition, "http_error_code_returned_equals", null)
      }

      redirect {
        host_name               = lookup(routing_rule.value.redirect, "host_name", null)
        http_redirect_code      = lookup(routing_rule.value.redirect, "http_redirect_code", null)
        protocol                = lookup(routing_rule.value.redirect, "protocol", null)
        replace_key_prefix_with = lookup(routing_rule.value.redirect, "replace_key_prefix_with", null)
        replace_key_with        = lookup(routing_rule.value.redirect, "replace_key_with", null)
      }
    }
  }
}

################################################################################
# Request Payment
################################################################################

resource "aws_s3_bucket_request_payment_configuration" "this" {
  count = var.request_payer != null ? 1 : 0

  bucket = aws_s3_bucket.this.id
  payer  = var.request_payer
}

################################################################################
# Acceleration
################################################################################

resource "aws_s3_bucket_accelerate_configuration" "this" {
  count = var.acceleration_status != null ? 1 : 0

  bucket = aws_s3_bucket.this.id
  status = var.acceleration_status
}

################################################################################
# Analytics
################################################################################

resource "aws_s3_bucket_analytics_configuration" "this" {
  for_each = var.analytics_configurations

  bucket = aws_s3_bucket.this.id
  name   = each.key

  dynamic "filter" {
    for_each = lookup(each.value, "filter", null) != null ? [each.value.filter] : []

    content {
      prefix = lookup(filter.value, "prefix", null)
      tags   = lookup(filter.value, "tags", {})
    }
  }

  dynamic "storage_class_analysis" {
    for_each = lookup(each.value, "storage_class_analysis", null) != null ? [each.value.storage_class_analysis] : []

    content {
      data_export {
        output_schema_version = "V_1"

        destination {
          s3_bucket_destination {
            bucket_arn = storage_class_analysis.value.destination_bucket_arn
            prefix     = lookup(storage_class_analysis.value, "destination_prefix", null)
          }
        }
      }
    }
  }
}

################################################################################
# Inventory
################################################################################

resource "aws_s3_bucket_inventory" "this" {
  for_each = var.inventory_configurations

  bucket = aws_s3_bucket.this.id
  name   = each.key

  included_object_versions = lookup(each.value, "included_object_versions", "All")
  enabled                  = lookup(each.value, "enabled", true)

  schedule {
    frequency = lookup(each.value, "frequency", "Weekly")
  }

  destination {
    bucket {
      bucket_arn = each.value.destination_bucket_arn
      prefix     = lookup(each.value, "destination_prefix", null)
      format     = lookup(each.value, "format", "CSV")
    }
  }

  optional_fields = lookup(each.value, "optional_fields", [])
}

################################################################################
# Metrics
################################################################################

resource "aws_s3_bucket_metric" "this" {
  for_each = var.metrics_configurations

  bucket = aws_s3_bucket.this.id
  name   = each.key

  dynamic "filter" {
    for_each = lookup(each.value, "filter", null) != null ? [each.value.filter] : []

    content {
      prefix = lookup(filter.value, "prefix", null)
      tags   = lookup(filter.value, "tags", {})
    }
  }
}
