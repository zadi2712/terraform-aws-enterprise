################################################################################
# ALB Module - Main Configuration
# Description: Application Load Balancer
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Module    = "alb"
      ManagedBy = "terraform"
    }
  )
}

# Add your resource configurations here
# Resources: aws_lb, aws_lb_target_group, aws_lb_listener
