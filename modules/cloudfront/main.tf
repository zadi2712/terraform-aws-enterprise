resource "aws_cloudfront_distribution" "this" {
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
