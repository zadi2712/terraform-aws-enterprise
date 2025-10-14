################################################################################
# SSM Outputs Module
# Purpose: Store Terraform layer outputs in AWS Systems Manager Parameter Store
# This enables both terraform_remote_state and SSM-based data retrieval
################################################################################

locals {
  # Convert outputs map to flattened parameter structure
  parameters = {
    for key, value in var.outputs : key => {
      name        = "/${var.parameter_prefix}/${var.project_name}/${var.environment}/${var.layer_name}/${key}"
      value       = jsonencode(value)
      type        = var.parameter_type
      description = try(var.output_descriptions[key], "Terraform output: ${key}")
      tier        = length(jsonencode(value)) > 4096 ? "Advanced" : "Standard"
    }
  }
}

################################################################################
# SSM Parameters for Terraform Outputs
################################################################################

resource "aws_ssm_parameter" "outputs" {
  for_each = local.parameters

  name        = each.value.name
  description = each.value.description
  type        = each.value.type
  tier        = each.value.tier
  value       = each.value.value

  tags = merge(
    var.tags,
    {
      Layer       = var.layer_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Purpose     = "Layer Output Storage"
    }
  )
}

################################################################################
# Summary Parameter (Optional)
# Stores all outputs in a single parameter for easy retrieval
################################################################################

resource "aws_ssm_parameter" "summary" {
  count = var.create_summary_parameter ? 1 : 0

  name        = "/${var.parameter_prefix}/${var.project_name}/${var.environment}/${var.layer_name}/_summary"
  description = "Summary of all ${var.layer_name} layer outputs"
  type        = var.parameter_type
  tier        = length(jsonencode(var.outputs)) > 4096 ? "Advanced" : "Standard"
  value       = jsonencode(var.outputs)

  tags = merge(
    var.tags,
    {
      Layer       = var.layer_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Purpose     = "Layer Output Summary"
    }
  )
}
