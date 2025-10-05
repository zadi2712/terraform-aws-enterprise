output "application_bucket_id" {
  description = "Application bucket ID"
  value       = module.application_bucket.bucket_id
}

output "logs_bucket_id" {
  description = "Logs bucket ID"
  value       = module.logs_bucket.bucket_id
}
