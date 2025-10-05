################################################################################
# DYNAMODB Module - Main Configuration
# Description: DynamoDB tables
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Module    = "dynamodb"
      ManagedBy = "terraform"
    }
  )
}

# Add your resource configurations here
# Resources: aws_dynamodb_table
