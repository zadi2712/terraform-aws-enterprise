################################################################################
# IAM Module - Variables
################################################################################

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "name" {
  description = "Resource name"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
