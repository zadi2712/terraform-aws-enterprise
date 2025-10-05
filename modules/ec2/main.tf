################################################################################
# EC2 Module - Main Configuration
# Description: EC2 instances with Auto Scaling
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Module    = "ec2"
      ManagedBy = "terraform"
    }
  )
}

# Add your resource configurations here
# Resources: aws_instance, aws_autoscaling_group, aws_launch_template
