#!/usr/bin/env python3
"""
Generate additional essential Terraform modules
"""

import os
from pathlib import Path

BASE_DIR = "/Users/diego/terraform-aws-enterprise"

ADDITIONAL_MODULES = {
    "alb": {
        "main.tf": '''resource "aws_lb" "this" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = var.security_groups
  subnets            = var.subnets

  enable_deletion_protection = var.enable_deletion_protection
  enable_http2              = var.enable_http2
  enable_cross_zone_load_balancing = true

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_lb_target_group" "this" {
  for_each = var.target_groups

  name     = each.key
  port     = each.value.port
  protocol = each.value.protocol
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = lookup(each.value, "health_check_matcher", "200")
    path                = lookup(each.value, "health_check_path", "/health")
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = lookup(each.value, "deregistration_delay", 30)

  tags = var.tags
}

resource "aws_lb_listener" "http" {
  count = var.create_http_listener ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  count = var.create_https_listener ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[var.default_target_group].arn
  }
}
''',
        "variables.tf": '''variable "name" { type = string }
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
''',
        "outputs.tf": '''output "lb_id" { value = aws_lb.this.id }
output "lb_arn" { value = aws_lb.this.arn }
output "lb_dns_name" { value = aws_lb.this.dns_name }
output "lb_zone_id" { value = aws_lb.this.zone_id }
output "target_group_arns" { value = { for k, v in aws_lb_target_group.this : k => v.arn } }
'''
    },
    
    "lambda": {
        "main.tf": '''resource "aws_lambda_function" "this" {
  filename         = var.filename
  function_name    = var.function_name
  role            = var.role_arn
  handler         = var.handler
  source_code_hash = filebase64sha256(var.filename)
  runtime         = var.runtime

  memory_size = var.memory_size
  timeout     = var.timeout

  environment {
    variables = var.environment_variables
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_config != null ? [var.dead_letter_config] : []
    content {
      target_arn = dead_letter_config.value.target_arn
    }
  }

  tags = merge(var.tags, { Name = var.function_name })
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}
''',
        "variables.tf": '''variable "function_name" { type = string }
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
''',
        "outputs.tf": '''output "function_arn" { value = aws_lambda_function.this.arn }
output "function_name" { value = aws_lambda_function.this.function_name }
output "invoke_arn" { value = aws_lambda_function.this.invoke_arn }
output "qualified_arn" { value = aws_lambda_function.this.qualified_arn }
'''
    },
    
    "dynamodb": {
        "main.tf": '''resource "aws_dynamodb_table" "this" {
  name           = var.table_name
  billing_mode   = var.billing_mode
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null
  hash_key       = var.hash_key
  range_key      = var.range_key

  dynamic "attribute" {
    for_each = var.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes
    content {
      name               = global_secondary_index.value.name
      hash_key           = global_secondary_index.value.hash_key
      range_key          = lookup(global_secondary_index.value, "range_key", null)
      projection_type    = global_secondary_index.value.projection_type
      non_key_attributes = lookup(global_secondary_index.value, "non_key_attributes", null)
      read_capacity      = var.billing_mode == "PROVISIONED" ? global_secondary_index.value.read_capacity : null
      write_capacity     = var.billing_mode == "PROVISIONED" ? global_secondary_index.value.write_capacity : null
    }
  }

  server_side_encryption {
    enabled     = var.enable_encryption
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  dynamic "ttl" {
    for_each = var.ttl_enabled ? [1] : []
    content {
      enabled        = true
      attribute_name = var.ttl_attribute_name
    }
  }

  tags = merge(var.tags, { Name = var.table_name })
}
''',
        "variables.tf": '''variable "table_name" { type = string }
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
''',
        "outputs.tf": '''output "table_id" { value = aws_dynamodb_table.this.id }
output "table_arn" { value = aws_dynamodb_table.this.arn }
output "table_name" { value = aws_dynamodb_table.this.name }
output "table_stream_arn" { value = aws_dynamodb_table.this.stream_arn }
'''
    },
    
    "cloudfront": {
        "main.tf": '''resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = var.is_ipv6_enabled
  comment             = var.comment
  default_root_object = var.default_root_object
  aliases             = var.aliases
  price_class         = var.price_class

  origin {
    domain_name = var.origin_domain_name
    origin_id   = var.origin_id

    dynamic "s3_origin_config" {
      for_each = var.origin_type == "s3" ? [1] : []
      content {
        origin_access_identity = var.origin_access_identity
      }
    }

    dynamic "custom_origin_config" {
      for_each = var.origin_type == "custom" ? [1] : []
      content {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  default_cache_behavior {
    allowed_methods  = var.allowed_methods
    cached_methods   = var.cached_methods
    target_origin_id = var.origin_id

    forwarded_values {
      query_string = var.forward_query_string
      cookies {
        forward = var.forward_cookies
      }
    }

    viewer_protocol_policy = var.viewer_protocol_policy
    min_ttl                = var.min_ttl
    default_ttl            = var.default_ttl
    max_ttl                = var.max_ttl
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn != null ? "sni-only" : null
    minimum_protocol_version       = var.minimum_protocol_version
  }

  tags = merge(var.tags, { Name = var.comment })
}
''',
        "variables.tf": '''variable "comment" { type = string }
variable "is_ipv6_enabled" { type = bool; default = true }
variable "default_root_object" { type = string; default = "index.html" }
variable "aliases" { type = list(string); default = [] }
variable "price_class" { type = string; default = "PriceClass_100" }
variable "origin_domain_name" { type = string }
variable "origin_id" { type = string }
variable "origin_type" { type = string; default = "s3" }
variable "origin_access_identity" { type = string; default = null }
variable "allowed_methods" { type = list(string); default = ["GET", "HEAD", "OPTIONS"] }
variable "cached_methods" { type = list(string); default = ["GET", "HEAD"] }
variable "forward_query_string" { type = bool; default = false }
variable "forward_cookies" { type = string; default = "none" }
variable "viewer_protocol_policy" { type = string; default = "redirect-to-https" }
variable "min_ttl" { type = number; default = 0 }
variable "default_ttl" { type = number; default = 3600 }
variable "max_ttl" { type = number; default = 86400 }
variable "geo_restriction_type" { type = string; default = "none" }
variable "geo_restriction_locations" { type = list(string); default = [] }
variable "acm_certificate_arn" { type = string; default = null }
variable "minimum_protocol_version" { type = string; default = "TLSv1.2_2021" }
variable "tags" { type = map(string); default = {} }
''',
        "outputs.tf": '''output "distribution_id" { value = aws_cloudfront_distribution.this.id }
output "distribution_arn" { value = aws_cloudfront_distribution.this.arn }
output "distribution_domain_name" { value = aws_cloudfront_distribution.this.domain_name }
output "distribution_hosted_zone_id" { value = aws_cloudfront_distribution.this.hosted_zone_id }
'''
    },
    
    "route53": {
        "main.tf": '''resource "aws_route53_record" "this" {
  for_each = var.records

  zone_id = var.zone_id
  name    = each.key
  type    = each.value.type
  ttl     = lookup(each.value, "ttl", 300)
  records = lookup(each.value, "records", [])

  dynamic "alias" {
    for_each = lookup(each.value, "alias", null) != null ? [each.value.alias] : []
    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = lookup(alias.value, "evaluate_target_health", false)
    }
  }
}

resource "aws_route53_health_check" "this" {
  for_each = var.health_checks

  fqdn              = each.value.fqdn
  port              = lookup(each.value, "port", 443)
  type              = lookup(each.value, "type", "HTTPS")
  resource_path     = lookup(each.value, "resource_path", "/")
  failure_threshold = lookup(each.value, "failure_threshold", 3)
  request_interval  = lookup(each.value, "request_interval", 30)

  tags = merge(var.tags, { Name = each.key })
}
''',
        "variables.tf": '''variable "zone_id" { type = string }
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
''',
        "outputs.tf": '''output "record_names" { value = { for k, v in aws_route53_record.this : k => v.name } }
output "record_fqdns" { value = { for k, v in aws_route53_record.this : k => v.fqdn } }
output "health_check_ids" { value = { for k, v in aws_route53_health_check.this : k => v.id } }
'''
    }
}

# Generate additional modules
print("🚀 Generating additional Terraform modules...")
for module_name, files in ADDITIONAL_MODULES.items():
    module_dir = f"{BASE_DIR}/modules/{module_name}"
    Path(module_dir).mkdir(parents=True, exist_ok=True)
    
    for filename, content in files.items():
        filepath = f"{module_dir}/{filename}"
        with open(filepath, "w") as f:
            f.write(content)
    
    print(f"  ✅ Created module: {module_name}")

print("\n✅ All additional modules generated successfully!")
