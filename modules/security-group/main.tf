################################################################################
# SECURITY-GROUP Module - Main Configuration
# Description: Security Groups
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Module    = "security-group"
      ManagedBy = "terraform"
    }
  )
}

# Add your resource configurations here
# Resources: aws_security_group, aws_security_group_rule
