variable "function_name" { type = string }
variable "filename" { type = string }
variable "role_arn" { type = string }
variable "handler" { type = string }
variable "runtime" { type = string; default = "python3.11" }
variable "memory_size" { type = number; default = 128 }
variable "timeout" { type = number; default = 3 }
variable "environment_variables" { type = map(string); default = {} }
variable "log_retention_days" { type = number; default = 7 }
variable "vpc_config" {
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}
variable "dead_letter_config" {
  type = object({
    target_arn = string
  })
  default = null
}
variable "tags" { type = map(string); default = {} }
