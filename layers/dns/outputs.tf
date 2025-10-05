output "hosted_zone_id" {
  description = "Hosted zone ID"
  value       = var.domain_name != "" ? aws_route53_zone.main[0].zone_id : null
}

output "name_servers" {
  description = "Name servers"
  value       = var.domain_name != "" ? aws_route53_zone.main[0].name_servers : null
}
