################################################################################
# CLOUDFRONT Module - Main Configuration
# Description: CloudFront distributions
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Module    = "cloudfront"
      ManagedBy = "terraform"
    }
  )
}

# Add your resource configurations here
# Resources: aws_cloudfront_distribution
