################################################################################
# RDS Module - Main Configuration
# Description: RDS database instances
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Module    = "rds"
      ManagedBy = "terraform"
    }
  )
}

# Add your resource configurations here
# Resources: aws_db_instance, aws_db_parameter_group
