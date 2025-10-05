resource "aws_route53_record" "this" {
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
