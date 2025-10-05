variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "logs_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 90
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
