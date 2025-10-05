variable "table_name" { type = string }
variable "billing_mode" { type = string; default = "PAY_PER_REQUEST" }
variable "read_capacity" { type = number; default = 5 }
variable "write_capacity" { type = number; default = 5 }
variable "hash_key" { type = string }
variable "range_key" { type = string; default = null }
variable "attributes" {
  type = list(object({
    name = string
    type = string
  }))
}
variable "global_secondary_indexes" {
  type = list(any)
  default = []
}
variable "enable_encryption" { type = bool; default = true }
variable "kms_key_arn" { type = string; default = null }
variable "enable_point_in_time_recovery" { type = bool; default = true }
variable "ttl_enabled" { type = bool; default = false }
variable "ttl_attribute_name" { type = string; default = "TimeToExist" }
variable "tags" { type = map(string); default = {} }
