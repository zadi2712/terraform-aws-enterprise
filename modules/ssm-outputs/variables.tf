################################################################################
# SSM Outputs Module - Variables
################################################################################

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "layer_name" {
  description = "Name of the Terraform layer (e.g., networking, security, compute)"
  type        = string
}

variable "outputs" {
  description = "Map of Terraform outputs to store in SSM Parameter Store"
  type        = any
}

variable "output_descriptions" {
  description = "Map of output names to their descriptions"
  type        = map(string)
  default     = {}
}

variable "parameter_prefix" {
  description = "Prefix for SSM parameter paths"
  type        = string
  default     = "terraform"
}

variable "parameter_type" {
  description = "Type of SSM parameter (String, StringList, or SecureString)"
  type        = string
  default     = "String"

  validation {
    condition     = contains(["String", "StringList", "SecureString"], var.parameter_type)
    error_message = "Parameter type must be String, StringList, or SecureString."
  }
}

variable "create_summary_parameter" {
  description = "Whether to create a summary parameter containing all outputs"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for SSM parameters"
  type        = map(string)
  default     = {}
}
