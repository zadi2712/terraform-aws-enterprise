variable "comment" {
  type = string
}

variable "is_ipv6_enabled" {
  type    = bool
  default = true
}

variable "default_root_object" {
  type    = string
  default = "index.html"
}

variable "aliases" {
  type    = list(string)
  default = []
}

variable "price_class" {
  type    = string
  default = "PriceClass_100"
}

variable "origin_domain_name" {
  type = string
}

variable "origin_id" {
  type = string
}

variable "origin_type" {
  type    = string
  default = "s3"
}

variable "origin_access_identity" {
  type    = string
  default = null
}

variable "allowed_methods" {
  type    = list(string)
  default = ["GET", "HEAD", "OPTIONS"]
}

variable "cached_methods" {
  type    = list(string)
  default = ["GET", "HEAD"]
}

variable "forward_query_string" {
  type    = bool
  default = false
}

variable "forward_cookies" {
  type    = string
  default = "none"
}

variable "viewer_protocol_policy" {
  type    = string
  default = "redirect-to-https"
}

variable "min_ttl" {
  type    = number
  default = 0
}

variable "default_ttl" {
  type    = number
  default = 3600
}

variable "max_ttl" {
  type    = number
  default = 86400
}

variable "geo_restriction_type" {
  type    = string
  default = "none"
}

variable "geo_restriction_locations" {
  type    = list(string)
  default = []
}

variable "acm_certificate_arn" {
  type    = string
  default = null
}

variable "minimum_protocol_version" {
  type    = string
  default = "TLSv1.2_2021"
}

variable "tags" {
  type    = map(string)
  default = {}
}
