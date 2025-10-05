variable "name" { type = string }
variable "internal" { type = bool; default = false }
variable "security_groups" { type = list(string) }
variable "subnets" { type = list(string) }
variable "vpc_id" { type = string }
variable "enable_deletion_protection" { type = bool; default = false }
variable "enable_http2" { type = bool; default = true }
variable "create_http_listener" { type = bool; default = true }
variable "create_https_listener" { type = bool; default = true }
variable "ssl_policy" { type = string; default = "ELBSecurityPolicy-TLS-1-2-2017-01" }
variable "certificate_arn" { type = string; default = "" }
variable "default_target_group" { type = string; default = "default" }
variable "target_groups" {
  type = map(object({
    port                    = number
    protocol                = string
    health_check_path       = optional(string)
    health_check_matcher    = optional(string)
    deregistration_delay    = optional(number)
  }))
}
variable "tags" { type = map(string); default = {} }
