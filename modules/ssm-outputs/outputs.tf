################################################################################
# SSM Outputs Module - Outputs
################################################################################

output "parameter_arns" {
  description = "ARNs of created SSM parameters"
  value = {
    for key, param in aws_ssm_parameter.outputs : key => param.arn
  }
}

output "parameter_names" {
  description = "Names of created SSM parameters"
  value = {
    for key, param in aws_ssm_parameter.outputs : key => param.name
  }
}

output "parameter_paths" {
  description = "Full paths of created SSM parameters (alias for parameter_names)"
  value = {
    for key, param in aws_ssm_parameter.outputs : key => param.name
  }
}

output "summary_parameter_arn" {
  description = "ARN of the summary parameter"
  value       = var.create_summary_parameter ? aws_ssm_parameter.summary[0].arn : null
}

output "summary_parameter_name" {
  description = "Name of the summary parameter"
  value       = var.create_summary_parameter ? aws_ssm_parameter.summary[0].name : null
}

output "parameter_count" {
  description = "Number of parameters created"
  value       = length(aws_ssm_parameter.outputs)
}
