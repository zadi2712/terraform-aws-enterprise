################################################################################
# Lambda Module - Outputs
# Version: 2.0
################################################################################

################################################################################
# Function Outputs
################################################################################

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "function_version" {
  description = "Latest published version of the Lambda function"
  value       = aws_lambda_function.this.version
}

output "function_qualified_arn" {
  description = "Qualified ARN of the Lambda function"
  value       = aws_lambda_function.this.qualified_arn
}

output "function_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.this.invoke_arn
}

output "function_last_modified" {
  description = "Date the function was last modified"
  value       = aws_lambda_function.this.last_modified
}

output "function_source_code_size" {
  description = "Size of the function deployment package in bytes"
  value       = aws_lambda_function.this.source_code_size
}

################################################################################
# IAM Role Outputs
################################################################################

output "role_arn" {
  description = "ARN of the Lambda execution role"
  value       = var.create_role ? aws_iam_role.lambda[0].arn : var.role_arn
}

output "role_name" {
  description = "Name of the Lambda execution role"
  value       = var.create_role ? aws_iam_role.lambda[0].name : null
}

output "role_id" {
  description = "ID of the Lambda execution role"
  value       = var.create_role ? aws_iam_role.lambda[0].id : null
}

################################################################################
# CloudWatch Log Group Outputs
################################################################################

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = var.create_log_group ? aws_cloudwatch_log_group.this[0].name : "/aws/lambda/${var.function_name}"
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = var.create_log_group ? aws_cloudwatch_log_group.this[0].arn : null
}

################################################################################
# Alias Outputs
################################################################################

output "alias_names" {
  description = "Map of alias names"
  value       = { for k, v in aws_lambda_alias.this : k => v.name }
}

output "alias_arns" {
  description = "Map of alias ARNs"
  value       = { for k, v in aws_lambda_alias.this : k => v.arn }
}

output "alias_invoke_arns" {
  description = "Map of alias invoke ARNs"
  value       = { for k, v in aws_lambda_alias.this : k => v.invoke_arn }
}

################################################################################
# Function URL Outputs
################################################################################

output "function_url" {
  description = "Lambda function URL"
  value       = var.create_function_url ? aws_lambda_function_url.this[0].function_url : null
}

output "function_url_id" {
  description = "Lambda function URL ID"
  value       = var.create_function_url ? aws_lambda_function_url.this[0].url_id : null
}

################################################################################
# Event Source Mapping Outputs
################################################################################

output "event_source_mapping_uuids" {
  description = "Map of event source mapping UUIDs"
  value       = { for k, v in aws_lambda_event_source_mapping.this : k => v.uuid }
}

output "event_source_mapping_states" {
  description = "Map of event source mapping states"
  value       = { for k, v in aws_lambda_event_source_mapping.this : k => v.state }
}

################################################################################
# Provisioned Concurrency Outputs
################################################################################

output "provisioned_concurrency_configs" {
  description = "Map of provisioned concurrency configurations"
  value = {
    for k, v in aws_lambda_provisioned_concurrency_config.this : k => {
      qualifier              = v.qualifier
      allocated_executions   = v.allocated_concurrent_executions
      available_executions   = v.available_concurrent_executions
      status                 = v.status
    }
  }
}

################################################################################
# Summary Output
################################################################################

output "lambda_info" {
  description = "Complete Lambda function information"
  value = {
    function_name       = aws_lambda_function.this.function_name
    function_arn        = aws_lambda_function.this.arn
    version             = aws_lambda_function.this.version
    runtime             = aws_lambda_function.this.runtime
    memory_size         = aws_lambda_function.this.memory_size
    timeout             = aws_lambda_function.this.timeout
    package_type        = aws_lambda_function.this.package_type
    architectures       = aws_lambda_function.this.architectures
    role_arn            = var.create_role ? aws_iam_role.lambda[0].arn : var.role_arn
    log_group_name      = var.create_log_group ? aws_cloudwatch_log_group.this[0].name : "/aws/lambda/${var.function_name}"
    aliases_count       = length(aws_lambda_alias.this)
    event_sources_count = length(aws_lambda_event_source_mapping.this)
    function_url        = var.create_function_url ? aws_lambda_function_url.this[0].function_url : null
  }
}
