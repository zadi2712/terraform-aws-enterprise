################################################################################
# IAM Module - Main Configuration
# Description: IAM roles and policies
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Module    = "iam"
      ManagedBy = "terraform"
    }
  )
}

# Add your resource configurations here
# Resources: aws_iam_role, aws_iam_policy, aws_iam_role_policy_attachment
