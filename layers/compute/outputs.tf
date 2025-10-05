output "ecs_cluster_id" {
  description = "ECS Cluster ID"
  value       = module.ecs_cluster.cluster_id
}

output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = module.ecs_cluster.cluster_name
}

output "alb_security_group_id" {
  description = "ALB Security Group ID"
  value       = module.alb_security_group.security_group_id
}
