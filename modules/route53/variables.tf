variable "zone_id" { type = string }
variable "records" {
  type = map(object({
    type    = string
    ttl     = optional(number)
    records = optional(list(string))
    alias = optional(object({
      name                   = string
      zone_id                = string
      evaluate_target_health = optional(bool)
    }))
  }))
  default = {}
}
variable "health_checks" {
  type = map(object({
    fqdn              = string
    port              = optional(number)
    type              = optional(string)
    resource_path     = optional(string)
    failure_threshold = optional(number)
    request_interval  = optional(number)
  }))
  default = {}
}
variable "tags" { type = map(string); default = {} }
