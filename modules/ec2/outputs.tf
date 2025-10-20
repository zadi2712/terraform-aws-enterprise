################################################################################
# EC2 Module - Outputs
# Version: 2.0
################################################################################

################################################################################
# Instance Outputs
################################################################################

output "instance_ids" {
  description = "List of instance IDs"
  value       = var.create_instance && !var.create_autoscaling_group ? aws_instance.this[*].id : []
}

output "instance_arns" {
  description = "List of instance ARNs"
  value       = var.create_instance && !var.create_autoscaling_group ? aws_instance.this[*].arn : []
}

output "private_ips" {
  description = "List of private IP addresses"
  value       = var.create_instance && !var.create_autoscaling_group ? aws_instance.this[*].private_ip : []
}

output "public_ips" {
  description = "List of public IP addresses"
  value       = var.create_instance && !var.create_autoscaling_group ? aws_instance.this[*].public_ip : []
}

output "instance_id" {
  description = "ID of the instance (first instance if multiple)"
  value       = var.create_instance && !var.create_autoscaling_group && length(aws_instance.this) > 0 ? aws_instance.this[0].id : null
}

output "instance_arn" {
  description = "ARN of the instance (first instance if multiple)"
  value       = var.create_instance && !var.create_autoscaling_group && length(aws_instance.this) > 0 ? aws_instance.this[0].arn : null
}

output "private_ip" {
  description = "Private IP of the instance (first instance if multiple)"
  value       = var.create_instance && !var.create_autoscaling_group && length(aws_instance.this) > 0 ? aws_instance.this[0].private_ip : null
}

output "public_ip" {
  description = "Public IP of the instance (first instance if multiple)"
  value       = var.create_instance && !var.create_autoscaling_group && length(aws_instance.this) > 0 ? aws_instance.this[0].public_ip : null
}

################################################################################
# IAM Outputs
################################################################################

output "iam_role_arn" {
  description = "ARN of the IAM role"
  value       = var.create_iam_instance_profile ? aws_iam_role.instance[0].arn : null
}

output "iam_role_name" {
  description = "Name of the IAM role"
  value       = var.create_iam_instance_profile ? aws_iam_role.instance[0].name : null
}

output "iam_instance_profile_arn" {
  description = "ARN of the IAM instance profile"
  value       = var.create_iam_instance_profile ? aws_iam_instance_profile.this[0].arn : null
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = var.create_iam_instance_profile ? aws_iam_instance_profile.this[0].name : null
}

################################################################################
# Launch Template Outputs
################################################################################

output "launch_template_id" {
  description = "ID of the launch template"
  value       = var.create_launch_template ? aws_launch_template.this[0].id : null
}

output "launch_template_arn" {
  description = "ARN of the launch template"
  value       = var.create_launch_template ? aws_launch_template.this[0].arn : null
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = var.create_launch_template ? aws_launch_template.this[0].latest_version : null
}

################################################################################
# Auto Scaling Group Outputs
################################################################################

output "autoscaling_group_id" {
  description = "Auto Scaling Group ID"
  value       = var.create_autoscaling_group ? aws_autoscaling_group.this[0].id : null
}

output "autoscaling_group_name" {
  description = "Auto Scaling Group name"
  value       = var.create_autoscaling_group ? aws_autoscaling_group.this[0].name : null
}

output "autoscaling_group_arn" {
  description = "Auto Scaling Group ARN"
  value       = var.create_autoscaling_group ? aws_autoscaling_group.this[0].arn : null
}

output "autoscaling_group_min_size" {
  description = "Minimum size of Auto Scaling Group"
  value       = var.create_autoscaling_group ? aws_autoscaling_group.this[0].min_size : null
}

output "autoscaling_group_max_size" {
  description = "Maximum size of Auto Scaling Group"
  value       = var.create_autoscaling_group ? aws_autoscaling_group.this[0].max_size : null
}

output "autoscaling_group_desired_capacity" {
  description = "Desired capacity of Auto Scaling Group"
  value       = var.create_autoscaling_group ? aws_autoscaling_group.this[0].desired_capacity : null
}

################################################################################
# Auto Scaling Policy Outputs
################################################################################

output "target_tracking_policy_arns" {
  description = "ARNs of target tracking policies"
  value       = { for k, v in aws_autoscaling_policy.target_tracking : k => v.arn }
}

output "step_scaling_policy_arns" {
  description = "ARNs of step scaling policies"
  value       = { for k, v in aws_autoscaling_policy.step_scaling : k => v.arn }
}

################################################################################
# Elastic IP Outputs
################################################################################

output "eip_ids" {
  description = "List of Elastic IP IDs"
  value       = aws_eip.this[*].id
}

output "eip_public_ips" {
  description = "List of Elastic IP addresses"
  value       = aws_eip.this[*].public_ip
}

output "eip_allocation_ids" {
  description = "List of Elastic IP allocation IDs"
  value       = aws_eip.this[*].allocation_id
}

################################################################################
# EBS Volume Outputs
################################################################################

output "additional_ebs_volume_ids" {
  description = "Map of additional EBS volume IDs"
  value       = { for k, v in aws_ebs_volume.additional : k => v.id }
}

output "additional_ebs_volume_arns" {
  description = "Map of additional EBS volume ARNs"
  value       = { for k, v in aws_ebs_volume.additional : k => v.arn }
}

################################################################################
# CloudWatch Alarm Outputs
################################################################################

output "cloudwatch_alarm_cpu_high_arn" {
  description = "ARN of CPU high alarm"
  value       = var.create_autoscaling_group && var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.cpu_high[0].arn : null
}

output "cloudwatch_alarm_cpu_low_arn" {
  description = "ARN of CPU low alarm"
  value       = var.create_autoscaling_group && var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.cpu_low[0].arn : null
}

################################################################################
# Summary Output
################################################################################

output "ec2_info" {
  description = "Complete EC2 resource information"
  value = {
    deployment_type = var.create_autoscaling_group ? "autoscaling" : "standalone"
    instance_count  = var.create_autoscaling_group ? var.desired_capacity : var.instance_count
    instance_type   = var.instance_type
    
    # Instance info
    instance_ids  = var.create_instance && !var.create_autoscaling_group ? aws_instance.this[*].id : []
    private_ips   = var.create_instance && !var.create_autoscaling_group ? aws_instance.this[*].private_ip : []
    
    # ASG info
    asg_name      = var.create_autoscaling_group ? aws_autoscaling_group.this[0].name : null
    asg_min_size  = var.create_autoscaling_group ? var.min_size : null
    asg_max_size  = var.create_autoscaling_group ? var.max_size : null
    
    # IAM info
    iam_role_arn  = var.create_iam_instance_profile ? aws_iam_role.instance[0].arn : null
  }
}
