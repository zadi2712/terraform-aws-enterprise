################################################################################
# VPC Endpoints Module - Variables
################################################################################

variable "vpc_id" {
  description = "ID of the VPC where endpoints will be created"
  type        = string

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must be valid and start with 'vpc-'."
  }
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC (required for security group rules)"
  type        = string
  default     = null

  validation {
    condition     = var.vpc_cidr == null || can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block or null."
  }
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "vpc"

  validation {
    condition     = length(var.name_prefix) > 0 && length(var.name_prefix) <= 20
    error_message = "Name prefix must be between 1 and 20 characters."
  }
}

################################################################################
# Subnet Configuration
################################################################################

variable "private_subnet_ids" {
  description = "List of private subnet IDs for interface endpoints"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.private_subnet_ids) == 0 || alltrue([for id in var.private_subnet_ids : can(regex("^subnet-", id))])
    error_message = "All subnet IDs must be valid and start with 'subnet-'."
  }
}

variable "route_table_ids" {
  description = "List of route table IDs for gateway endpoints (S3, DynamoDB)"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.route_table_ids) == 0 || alltrue([for id in var.route_table_ids : can(regex("^rtb-", id))])
    error_message = "All route table IDs must be valid and start with 'rtb-'."
  }
}

################################################################################
# Security Group Configuration
################################################################################

variable "create_security_group" {
  description = "Whether to create a security group for VPC endpoints"
  type        = bool
  default     = true
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to endpoints (used if create_security_group is false)"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.security_group_ids) == 0 || alltrue([for id in var.security_group_ids : can(regex("^sg-", id))])
    error_message = "All security group IDs must be valid and start with 'sg-'."
  }
}

################################################################################
# Endpoint Configuration
################################################################################

variable "endpoints" {
  description = <<-EOT
    Map of VPC endpoints to create. Key is the endpoint name, value is a map with:
    - service: AWS service name (e.g., 'ec2', 's3', 'dynamodb')
    - service_type: 'Interface' or 'Gateway' (default: 'Interface')
    - private_dns_enabled: Enable private DNS for interface endpoints (default: true)
    - subnet_ids: List of subnet IDs (optional, defaults to var.private_subnet_ids)
    - security_group_ids: List of security group IDs (optional)
    - route_table_ids: List of route table IDs for gateway endpoints (optional)
    - policy: IAM policy document for the endpoint (optional)
    - tags: Additional tags for the endpoint (optional)
    - timeout_create: Timeout for create operation (default: '10m')
    - timeout_update: Timeout for update operation (default: '10m')
    - timeout_delete: Timeout for delete operation (default: '10m')
  EOT
  type = map(object({
    service             = string
    service_type        = optional(string, "Interface")
    private_dns_enabled = optional(bool, true)
    subnet_ids          = optional(list(string), [])
    security_group_ids  = optional(list(string), [])
    route_table_ids     = optional(list(string), [])
    policy              = optional(string, null)
    auto_accept         = optional(bool, null)
    tags                = optional(map(string), {})
    timeout_create      = optional(string, "10m")
    timeout_update      = optional(string, "10m")
    timeout_delete      = optional(string, "10m")
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.endpoints : contains(["Interface", "Gateway"], v.service_type)
    ])
    error_message = "Service type must be either 'Interface' or 'Gateway'."
  }
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "Common tags to apply to all VPC endpoint resources"
  type        = map(string)
  default     = {}
}
