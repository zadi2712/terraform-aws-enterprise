output "record_names" { value = { for k, v in aws_route53_record.this : k => v.name } }
output "record_fqdns" { value = { for k, v in aws_route53_record.this : k => v.fqdn } }
output "health_check_ids" { value = { for k, v in aws_route53_health_check.this : k => v.id } }
