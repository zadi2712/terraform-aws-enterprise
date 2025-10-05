################################################################################
# ROUTE53 Module - Main Configuration
# Description: Route53 DNS records
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Module    = "route53"
      ManagedBy = "terraform"
    }
  )
}

# Add your resource configurations here
# Resources: aws_route53_zone, aws_route53_record
