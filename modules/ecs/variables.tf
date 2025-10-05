variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "container_insights_enabled" {
  description = "Enable Container Insights"
  type        = bool
  default     = true
}

variable "capacity_providers" {
  description = "Capacity providers"
  type        = list(string)
  default     = ["FARGATE", "FARGATE_SPOT"]
}

variable "default_capacity_provider_strategy" {
  description = "Default capacity provider strategy"
  type        = list(any)
  default     = []
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
