################################################################################
# LAMBDA Module - Main Configuration
# Description: Lambda functions
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Module    = "lambda"
      ManagedBy = "terraform"
    }
  )
}

# Add your resource configurations here
# Resources: aws_lambda_function, aws_lambda_permission
