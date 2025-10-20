################################################################################
# Lambda Module - Enterprise Serverless Functions
# Version: 2.0
# Description: AWS Lambda functions with IAM, VPC, layers, and event sources
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  common_tags = merge(
    var.tags,
    {
      Module    = "lambda"
      ManagedBy = "terraform"
    }
  )
}

################################################################################
# IAM Execution Role
################################################################################

resource "aws_iam_role" "lambda" {
  count = var.create_role ? 1 : 0

  name                 = "${var.function_name}-role"
  description          = "Execution role for Lambda function ${var.function_name}"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${var.function_name}-role"
  })
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  count = var.create_role ? 1 : 0

  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC execution policy (if VPC config provided)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count = var.create_role && var.vpc_config != null ? 1 : 0

  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Additional managed policies
resource "aws_iam_role_policy_attachment" "additional" {
  for_each = var.create_role ? var.attach_policy_arns : {}

  role       = aws_iam_role.lambda[0].name
  policy_arn = each.value
}

# Inline policies
resource "aws_iam_role_policy" "inline" {
  for_each = var.create_role ? var.inline_policies : {}

  name   = each.key
  role   = aws_iam_role.lambda[0].id
  policy = each.value
}

################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "this" {
  count = var.create_log_group ? 1 : 0

  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_id

  tags = local.common_tags
}

################################################################################
# Lambda Function
################################################################################

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = var.description
  role          = var.create_role ? aws_iam_role.lambda[0].arn : var.role_arn

  # Package configuration
  filename         = var.package_type == "Zip" && var.filename != null ? var.filename : null
  s3_bucket        = var.package_type == "Zip" && var.s3_bucket != null ? var.s3_bucket : null
  s3_key           = var.package_type == "Zip" && var.s3_key != null ? var.s3_key : null
  s3_object_version = var.package_type == "Zip" && var.s3_object_version != null ? var.s3_object_version : null
  source_code_hash = var.package_type == "Zip" && var.filename != null ? filebase64sha256(var.filename) : var.source_code_hash
  
  # Container image
  image_uri    = var.package_type == "Image" ? var.image_uri : null
  package_type = var.package_type

  # Runtime configuration
  handler       = var.package_type == "Zip" ? var.handler : null
  runtime       = var.package_type == "Zip" ? var.runtime : null
  architectures = var.architectures

  # Resource configuration
  memory_size                    = var.memory_size
  timeout                        = var.timeout
  reserved_concurrent_executions = var.reserved_concurrent_executions
  publish                        = var.publish

  # Layers
  layers = var.layers

  # Environment variables
  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    
    content {
      variables = var.environment_variables
    }
  }

  # VPC configuration
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
      ipv6_allowed_for_dual_stack = lookup(vpc_config.value, "ipv6_allowed_for_dual_stack", null)
    }
  }

  # Dead letter config
  dynamic "dead_letter_config" {
    for_each = var.dead_letter_config != null ? [var.dead_letter_config] : []
    
    content {
      target_arn = dead_letter_config.value.target_arn
    }
  }

  # Tracing
  dynamic "tracing_config" {
    for_each = var.tracing_mode != null ? [1] : []
    
    content {
      mode = var.tracing_mode
    }
  }

  # EFS file system
  dynamic "file_system_config" {
    for_each = var.file_system_config != null ? [var.file_system_config] : []
    
    content {
      arn              = file_system_config.value.arn
      local_mount_path = file_system_config.value.local_mount_path
    }
  }

  # Image configuration (for container images)
  dynamic "image_config" {
    for_each = var.package_type == "Image" && var.image_config != null ? [var.image_config] : []
    
    content {
      command           = lookup(image_config.value, "command", null)
      entry_point       = lookup(image_config.value, "entry_point", null)
      working_directory = lookup(image_config.value, "working_directory", null)
    }
  }

  # Ephemeral storage
  dynamic "ephemeral_storage" {
    for_each = var.ephemeral_storage_size != null ? [1] : []
    
    content {
      size = var.ephemeral_storage_size
    }
  }

  # Snap start (for Java functions)
  dynamic "snap_start" {
    for_each = var.snap_start_enabled ? [1] : []
    
    content {
      apply_on = "PublishedVersions"
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = var.function_name
    }
  )

  depends_on = [
    aws_iam_role.lambda,
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_cloudwatch_log_group.this
  ]
}

################################################################################
# Lambda Aliases
################################################################################

resource "aws_lambda_alias" "this" {
  for_each = var.aliases

  name             = each.key
  description      = lookup(each.value, "description", null)
  function_name    = aws_lambda_function.this.function_name
  function_version = lookup(each.value, "function_version", "$LATEST")

  # Routing configuration for weighted deployments
  dynamic "routing_config" {
    for_each = lookup(each.value, "routing_config", null) != null ? [each.value.routing_config] : []
    
    content {
      additional_version_weights = routing_config.value.additional_version_weights
    }
  }
}

################################################################################
# Provisioned Concurrency
################################################################################

resource "aws_lambda_provisioned_concurrency_config" "this" {
  for_each = var.provisioned_concurrency

  function_name                     = aws_lambda_function.this.function_name
  qualifier                         = each.value.qualifier
  provisioned_concurrent_executions = each.value.concurrent_executions
}

################################################################################
# Lambda Permissions
################################################################################

resource "aws_lambda_permission" "this" {
  for_each = var.permissions

  statement_id       = each.key
  action             = lookup(each.value, "action", "lambda:InvokeFunction")
  function_name      = aws_lambda_function.this.function_name
  principal          = each.value.principal
  source_arn         = lookup(each.value, "source_arn", null)
  source_account     = lookup(each.value, "source_account", null)
  qualifier          = lookup(each.value, "qualifier", null)
  event_source_token = lookup(each.value, "event_source_token", null)
}

################################################################################
# Event Source Mappings
################################################################################

resource "aws_lambda_event_source_mapping" "this" {
  for_each = var.event_source_mappings

  event_source_arn  = each.value.event_source_arn
  function_name     = aws_lambda_function.this.function_name
  starting_position = lookup(each.value, "starting_position", null)
  batch_size        = lookup(each.value, "batch_size", null)
  enabled           = lookup(each.value, "enabled", true)

  # Filter criteria
  dynamic "filter_criteria" {
    for_each = lookup(each.value, "filter_criteria", null) != null ? [each.value.filter_criteria] : []
    
    content {
      dynamic "filter" {
        for_each = filter_criteria.value.filters
        
        content {
          pattern = filter.value.pattern
        }
      }
    }
  }

  # Destination config for failures
  dynamic "destination_config" {
    for_each = lookup(each.value, "destination_config", null) != null ? [each.value.destination_config] : []
    
    content {
      dynamic "on_failure" {
        for_each = lookup(destination_config.value, "on_failure", null) != null ? [destination_config.value.on_failure] : []
        
        content {
          destination_arn = on_failure.value.destination_arn
        }
      }
    }
  }

  maximum_batching_window_in_seconds = lookup(each.value, "maximum_batching_window_in_seconds", null)
  maximum_record_age_in_seconds      = lookup(each.value, "maximum_record_age_in_seconds", null)
  maximum_retry_attempts             = lookup(each.value, "maximum_retry_attempts", null)
  parallelization_factor             = lookup(each.value, "parallelization_factor", null)
  tumbling_window_in_seconds         = lookup(each.value, "tumbling_window_in_seconds", null)
  bisect_batch_on_function_error     = lookup(each.value, "bisect_batch_on_function_error", null)
  function_response_types            = lookup(each.value, "function_response_types", null)
}

################################################################################
# Lambda Function URL
################################################################################

resource "aws_lambda_function_url" "this" {
  count = var.create_function_url ? 1 : 0

  function_name      = aws_lambda_function.this.function_name
  authorization_type = var.function_url_authorization_type
  invoke_mode        = var.function_url_invoke_mode

  dynamic "cors" {
    for_each = var.function_url_cors != null ? [var.function_url_cors] : []
    
    content {
      allow_credentials = lookup(cors.value, "allow_credentials", null)
      allow_headers     = lookup(cors.value, "allow_headers", null)
      allow_methods     = lookup(cors.value, "allow_methods", null)
      allow_origins     = lookup(cors.value, "allow_origins", null)
      expose_headers    = lookup(cors.value, "expose_headers", null)
      max_age           = lookup(cors.value, "max_age", null)
    }
  }
}
