################################################################################
# Lambda Module - Variables
# Version: 2.0
################################################################################

################################################################################
# Required Variables
################################################################################

variable "function_name" {
  description = "Unique name for the Lambda function"
  type        = string
}

################################################################################
# Function Configuration
################################################################################

variable "description" {
  description = "Description of the Lambda function"
  type        = string
  default     = ""
}

variable "handler" {
  description = "Function entry point (e.g., index.handler)"
  type        = string
  default     = null
}

variable "runtime" {
  description = "Lambda runtime (e.g., python3.11, nodejs20.x, java17)"
  type        = string
  default     = "python3.11"
}

variable "architectures" {
  description = "Instruction set architecture (x86_64 or arm64)"
  type        = list(string)
  default     = ["x86_64"]
  
  validation {
    condition     = alltrue([for arch in var.architectures : contains(["x86_64", "arm64"], arch)])
    error_message = "Architectures must be x86_64 or arm64"
  }
}

################################################################################
# Package Configuration
################################################################################

variable "package_type" {
  description = "Lambda deployment package type (Zip or Image)"
  type        = string
  default     = "Zip"
  
  validation {
    condition     = contains(["Zip", "Image"], var.package_type)
    error_message = "package_type must be Zip or Image"
  }
}

variable "filename" {
  description = "Path to the function's deployment package (zip file)"
  type        = string
  default     = null
}

variable "s3_bucket" {
  description = "S3 bucket containing the function's deployment package"
  type        = string
  default     = null
}

variable "s3_key" {
  description = "S3 key of the function's deployment package"
  type        = string
  default     = null
}

variable "s3_object_version" {
  description = "S3 object version of the function's deployment package"
  type        = string
  default     = null
}

variable "source_code_hash" {
  description = "Base64-encoded SHA256 hash of the package file"
  type        = string
  default     = null
}

variable "image_uri" {
  description = "ECR image URI for container-based Lambda"
  type        = string
  default     = null
}

variable "image_config" {
  description = "Container image configuration"
  type = object({
    command           = optional(list(string))
    entry_point       = optional(list(string))
    working_directory = optional(string)
  })
  default = null
}

################################################################################
# Resource Configuration
################################################################################

variable "memory_size" {
  description = "Amount of memory in MB (128-10240)"
  type        = number
  default     = 128
  
  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "memory_size must be between 128 and 10240 MB"
  }
}

variable "timeout" {
  description = "Function timeout in seconds (1-900)"
  type        = number
  default     = 3
  
  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "timeout must be between 1 and 900 seconds"
  }
}

variable "ephemeral_storage_size" {
  description = "Ephemeral storage size in MB (512-10240)"
  type        = number
  default     = null
  
  validation {
    condition     = var.ephemeral_storage_size == null || (var.ephemeral_storage_size >= 512 && var.ephemeral_storage_size <= 10240)
    error_message = "ephemeral_storage_size must be between 512 and 10240 MB"
  }
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions for this function"
  type        = number
  default     = null
}

################################################################################
# IAM Configuration
################################################################################

variable "create_role" {
  description = "Whether to create IAM role for Lambda"
  type        = bool
  default     = true
}

variable "role_arn" {
  description = "ARN of existing IAM role to use (if create_role is false)"
  type        = string
  default     = null
}

variable "attach_policy_arns" {
  description = "Map of additional managed policy ARNs to attach to Lambda role"
  type        = map(string)
  default     = {}
}

variable "inline_policies" {
  description = "Map of inline policies to add to Lambda role"
  type        = map(string)
  default     = {}
}

################################################################################
# Network Configuration
################################################################################

variable "vpc_config" {
  description = "VPC configuration for Lambda function"
  type = object({
    subnet_ids                  = list(string)
    security_group_ids          = list(string)
    ipv6_allowed_for_dual_stack = optional(bool)
  })
  default = null
}

################################################################################
# Environment Variables
################################################################################

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

################################################################################
# Dead Letter Configuration
################################################################################

variable "dead_letter_config" {
  description = "Dead letter queue configuration (SNS or SQS ARN)"
  type = object({
    target_arn = string
  })
  default = null
}

################################################################################
# Logging Configuration
################################################################################

variable "create_log_group" {
  description = "Whether to create CloudWatch log group"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "log_kms_key_id" {
  description = "KMS key ID for encrypting logs"
  type        = string
  default     = null
}

################################################################################
# Tracing Configuration
################################################################################

variable "tracing_mode" {
  description = "X-Ray tracing mode (Active or PassThrough)"
  type        = string
  default     = null
  
  validation {
    condition     = var.tracing_mode == null || contains(["Active", "PassThrough"], var.tracing_mode)
    error_message = "tracing_mode must be Active or PassThrough"
  }
}

################################################################################
# Layers Configuration
################################################################################

variable "layers" {
  description = "List of Lambda layer ARNs"
  type        = list(string)
  default     = []
}

################################################################################
# Versioning and Aliases
################################################################################

variable "publish" {
  description = "Whether to publish creation/change as new version"
  type        = bool
  default     = false
}

variable "aliases" {
  description = "Map of aliases to create"
  type = map(object({
    description      = optional(string)
    function_version = optional(string, "$LATEST")
    routing_config = optional(object({
      additional_version_weights = map(number)
    }))
  }))
  default = {}
}

################################################################################
# Provisioned Concurrency
################################################################################

variable "provisioned_concurrency" {
  description = "Map of provisioned concurrency configurations"
  type = map(object({
    qualifier              = string
    concurrent_executions  = number
  }))
  default = {}
}

################################################################################
# Permissions
################################################################################

variable "permissions" {
  description = "Map of Lambda permissions to grant"
  type = map(object({
    principal          = string
    action             = optional(string, "lambda:InvokeFunction")
    source_arn         = optional(string)
    source_account     = optional(string)
    qualifier          = optional(string)
    event_source_token = optional(string)
  }))
  default = {}
}

################################################################################
# Event Source Mappings
################################################################################

variable "event_source_mappings" {
  description = "Map of event source mappings (SQS, Kinesis, DynamoDB)"
  type = map(object({
    event_source_arn                   = string
    starting_position                  = optional(string)
    batch_size                         = optional(number)
    enabled                            = optional(bool, true)
    maximum_batching_window_in_seconds = optional(number)
    maximum_record_age_in_seconds      = optional(number)
    maximum_retry_attempts             = optional(number)
    parallelization_factor             = optional(number)
    tumbling_window_in_seconds         = optional(number)
    bisect_batch_on_function_error     = optional(bool)
    function_response_types            = optional(list(string))
    filter_criteria = optional(object({
      filters = list(object({
        pattern = string
      }))
    }))
    destination_config = optional(object({
      on_failure = optional(object({
        destination_arn = string
      }))
    }))
  }))
  default = {}
}

################################################################################
# Function URL
################################################################################

variable "create_function_url" {
  description = "Whether to create a Lambda function URL"
  type        = bool
  default     = false
}

variable "function_url_authorization_type" {
  description = "Authorization type for function URL (AWS_IAM or NONE)"
  type        = string
  default     = "AWS_IAM"
  
  validation {
    condition     = contains(["AWS_IAM", "NONE"], var.function_url_authorization_type)
    error_message = "function_url_authorization_type must be AWS_IAM or NONE"
  }
}

variable "function_url_invoke_mode" {
  description = "Invoke mode for function URL (BUFFERED or RESPONSE_STREAM)"
  type        = string
  default     = "BUFFERED"
  
  validation {
    condition     = contains(["BUFFERED", "RESPONSE_STREAM"], var.function_url_invoke_mode)
    error_message = "function_url_invoke_mode must be BUFFERED or RESPONSE_STREAM"
  }
}

variable "function_url_cors" {
  description = "CORS configuration for function URL"
  type = object({
    allow_credentials = optional(bool)
    allow_headers     = optional(list(string))
    allow_methods     = optional(list(string))
    allow_origins     = optional(list(string))
    expose_headers    = optional(list(string))
    max_age           = optional(number)
  })
  default = null
}

################################################################################
# EFS Configuration
################################################################################

variable "file_system_config" {
  description = "EFS file system configuration"
  type = object({
    arn              = string
    local_mount_path = string
  })
  default = null
}

################################################################################
# SnapStart Configuration
################################################################################

variable "snap_start_enabled" {
  description = "Enable SnapStart for Java functions"
  type        = bool
  default     = false
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
