################################################################################
# ECS Module - Main Configuration
# Description: ECS Cluster and Services
################################################################################

locals {
  common_tags = merge(
    var.tags,
    {
      Module    = "ecs"
      ManagedBy = "terraform"
    }
  )
}

# Add your resource configurations here
# Resources: aws_ecs_cluster, aws_ecs_service, aws_ecs_task_definition
