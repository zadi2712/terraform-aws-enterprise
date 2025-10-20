################################################################################
# EC2 Module - Enterprise Instance Management
# Version: 2.0
# Description: EC2 instances with Auto Scaling, Launch Templates, and monitoring
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  common_tags = merge(
    var.tags,
    {
      Module    = "ec2"
      ManagedBy = "terraform"
    }
  )

  # Instance name with optional index
  instance_name = var.instance_count > 1 ? "${var.name}-${format("%02d", count.index + 1)}" : var.name
}

################################################################################
# IAM Instance Profile
################################################################################

resource "aws_iam_role" "instance" {
  count = var.create_iam_instance_profile ? 1 : 0
  name  = "${var.name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${var.name}-instance-role"
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.create_iam_instance_profile && var.enable_ssm_management ? 1 : 0
  role       = aws_iam_role.instance[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  count      = var.create_iam_instance_profile && var.enable_cloudwatch_agent ? 1 : 0
  role       = aws_iam_role.instance[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "custom" {
  for_each = var.create_iam_instance_profile ? var.iam_role_policy_arns : {}

  role       = aws_iam_role.instance[0].name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "this" {
  count = var.create_iam_instance_profile ? 1 : 0
  name  = "${var.name}-instance-profile"
  role  = aws_iam_role.instance[0].name

  tags = merge(local.common_tags, {
    Name = "${var.name}-instance-profile"
  })
}

################################################################################
# Launch Template (for ASG or standalone)
################################################################################

resource "aws_launch_template" "this" {
  count = var.create_launch_template ? 1 : 0

  name_prefix   = "${var.name}-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = var.vpc_security_group_ids

  iam_instance_profile {
    name = var.create_iam_instance_profile ? aws_iam_instance_profile.this[0].name : var.iam_instance_profile_name
  }

  # User data
  user_data = var.user_data != null ? var.user_data : (var.user_data_base64 != null ? var.user_data_base64 : null)

  # Block device mappings
  dynamic "block_device_mappings" {
    for_each = var.block_device_mappings

    content {
      device_name = block_device_mappings.value.device_name

      ebs {
        volume_size           = lookup(block_device_mappings.value, "volume_size", 30)
        volume_type           = lookup(block_device_mappings.value, "volume_type", "gp3")
        iops                  = lookup(block_device_mappings.value, "iops", null)
        throughput            = lookup(block_device_mappings.value, "throughput", null)
        delete_on_termination = lookup(block_device_mappings.value, "delete_on_termination", true)
        encrypted             = lookup(block_device_mappings.value, "encrypted", true)
        kms_key_id            = lookup(block_device_mappings.value, "kms_key_id", var.ebs_kms_key_id)
      }
    }
  }

  # Monitoring
  monitoring {
    enabled = var.enable_monitoring
  }

  # Network interfaces configuration
  dynamic "network_interfaces" {
    for_each = var.associate_public_ip_address != null ? [1] : []

    content {
      associate_public_ip_address = var.associate_public_ip_address
      delete_on_termination       = true
      security_groups             = var.vpc_security_group_ids
    }
  }

  # Metadata options (IMDSv2)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = var.require_imdsv2 ? "required" : "optional"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = var.enable_instance_metadata_tags ? "enabled" : "disabled"
  }

  # Instance tags
  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.common_tags,
      { Name = var.name }
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      local.common_tags,
      { Name = "${var.name}-volume" }
    )
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-launch-template"
  })

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Standalone EC2 Instance
################################################################################

resource "aws_instance" "this" {
  count = var.create_instance && !var.create_autoscaling_group ? var.instance_count : 0

  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  subnet_id              = var.subnet_id != null ? var.subnet_id : (length(var.subnet_ids) > 0 ? var.subnet_ids[count.index % length(var.subnet_ids)] : null)
  vpc_security_group_ids = var.vpc_security_group_ids

  iam_instance_profile = var.create_iam_instance_profile ? aws_iam_instance_profile.this[0].name : var.iam_instance_profile_name

  associate_public_ip_address = var.associate_public_ip_address
  monitoring                  = var.enable_monitoring
  ebs_optimized              = var.ebs_optimized

  user_data                   = var.user_data
  user_data_base64            = var.user_data_base64
  user_data_replace_on_change = var.user_data_replace_on_change

  # Root block device
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    iops                  = var.root_volume_iops
    throughput            = var.root_volume_throughput
    delete_on_termination = var.root_delete_on_termination
    encrypted             = var.root_volume_encrypted
    kms_key_id            = var.ebs_kms_key_id
  }

  # Additional EBS volumes
  dynamic "ebs_block_device" {
    for_each = var.ebs_block_devices

    content {
      device_name           = ebs_block_device.value.device_name
      volume_size           = lookup(ebs_block_device.value, "volume_size", 50)
      volume_type           = lookup(ebs_block_device.value, "volume_type", "gp3")
      iops                  = lookup(ebs_block_device.value, "iops", null)
      throughput            = lookup(ebs_block_device.value, "throughput", null)
      delete_on_termination = lookup(ebs_block_device.value, "delete_on_termination", true)
      encrypted             = lookup(ebs_block_device.value, "encrypted", true)
      kms_key_id            = lookup(ebs_block_device.value, "kms_key_id", var.ebs_kms_key_id)
    }
  }

  # Metadata options (IMDSv2)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = var.require_imdsv2 ? "required" : "optional"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = var.enable_instance_metadata_tags ? "enabled" : "disabled"
  }

  # Credit specification for T instances
  dynamic "credit_specification" {
    for_each = can(regex("^t[2-4]", var.instance_type)) ? [1] : []

    content {
      cpu_credits = var.cpu_credits
    }
  }

  # Lifecycle
  lifecycle {
    ignore_changes = var.ignore_ami_changes ? [ami] : []
  }

  tags = merge(
    local.common_tags,
    {
      Name = var.instance_count > 1 ? "${var.name}-${format("%02d", count.index + 1)}" : var.name
    }
  )
}

################################################################################
# Auto Scaling Group
################################################################################

resource "aws_autoscaling_group" "this" {
  count = var.create_autoscaling_group ? 1 : 0

  name                = "${var.name}-asg"
  vpc_zone_identifier = var.subnet_ids
  
  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period
  default_cooldown          = var.default_cooldown
  
  enabled_metrics           = var.enabled_metrics
  metrics_granularity       = var.metrics_granularity

  termination_policies      = var.termination_policies
  suspended_processes       = var.suspended_processes

  # Launch template
  launch_template {
    id      = var.create_launch_template ? aws_launch_template.this[0].id : var.launch_template_id
    version = var.launch_template_version
  }

  # Instance refresh
  dynamic "instance_refresh" {
    for_each = var.instance_refresh_enabled ? [1] : []

    content {
      strategy = "Rolling"
      
      preferences {
        min_healthy_percentage = var.instance_refresh_min_healthy_percentage
        instance_warmup        = var.instance_refresh_instance_warmup
      }
    }
  }

  # Target group attachments
  target_group_arns = var.target_group_arns

  # Warm pool (optional)
  dynamic "warm_pool" {
    for_each = var.warm_pool_enabled ? [1] : []

    content {
      pool_state                  = var.warm_pool_state
      min_size                    = var.warm_pool_min_size
      max_group_prepared_capacity = var.warm_pool_max_group_prepared_capacity
    }
  }

  # Tags
  dynamic "tag" {
    for_each = merge(
      local.common_tags,
      {
        Name = var.name
      }
    )

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

################################################################################
# Auto Scaling Policies
################################################################################

resource "aws_autoscaling_policy" "target_tracking" {
  for_each = var.create_autoscaling_group ? var.target_tracking_policies : {}

  name                   = "${var.name}-${each.key}"
  autoscaling_group_name = aws_autoscaling_group.this[0].name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = each.value.predefined_metric_type
      resource_label         = lookup(each.value, "resource_label", null)
    }

    target_value     = each.value.target_value
    disable_scale_in = lookup(each.value, "disable_scale_in", false)
  }
}

resource "aws_autoscaling_policy" "step_scaling" {
  for_each = var.create_autoscaling_group ? var.step_scaling_policies : {}

  name                   = "${var.name}-${each.key}"
  autoscaling_group_name = aws_autoscaling_group.this[0].name
  policy_type            = "StepScaling"
  adjustment_type        = each.value.adjustment_type
  
  dynamic "step_adjustment" {
    for_each = each.value.step_adjustments

    content {
      scaling_adjustment          = step_adjustment.value.scaling_adjustment
      metric_interval_lower_bound = lookup(step_adjustment.value, "metric_interval_lower_bound", null)
      metric_interval_upper_bound = lookup(step_adjustment.value, "metric_interval_upper_bound", null)
    }
  }

  metric_aggregation_type = lookup(each.value, "metric_aggregation_type", "Average")
}

################################################################################
# Auto Scaling Schedules
################################################################################

resource "aws_autoscaling_schedule" "this" {
  for_each = var.create_autoscaling_group ? var.autoscaling_schedules : {}

  scheduled_action_name  = each.key
  autoscaling_group_name = aws_autoscaling_group.this[0].name
  
  min_size         = lookup(each.value, "min_size", null)
  max_size         = lookup(each.value, "max_size", null)
  desired_capacity = lookup(each.value, "desired_capacity", null)
  
  recurrence = lookup(each.value, "recurrence", null)
  start_time = lookup(each.value, "start_time", null)
  end_time   = lookup(each.value, "end_time", null)
}

################################################################################
# CloudWatch Alarms for Auto Scaling
################################################################################

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = var.create_autoscaling_group && var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_high_threshold
  alarm_description   = "CPU utilization is too high"
  alarm_actions       = var.alarm_actions

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this[0].name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  count = var.create_autoscaling_group && var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.name}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_low_threshold
  alarm_description   = "CPU utilization is too low"
  alarm_actions       = var.alarm_actions

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this[0].name
  }

  tags = local.common_tags
}

################################################################################
# Elastic IP (for standalone instances)
################################################################################

resource "aws_eip" "this" {
  count = var.create_instance && var.allocate_eip && !var.create_autoscaling_group ? var.instance_count : 0

  instance = aws_instance.this[count.index].id
  domain   = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = var.instance_count > 1 ? "${var.name}-eip-${format("%02d", count.index + 1)}" : "${var.name}-eip"
    }
  )

  depends_on = [aws_instance.this]
}

################################################################################
# Additional EBS Volumes (standalone)
################################################################################

resource "aws_ebs_volume" "additional" {
  for_each = var.create_instance && !var.create_autoscaling_group ? var.additional_ebs_volumes : {}

  availability_zone = var.availability_zone
  size              = each.value.size
  type              = lookup(each.value, "type", "gp3")
  iops              = lookup(each.value, "iops", null)
  throughput        = lookup(each.value, "throughput", null)
  encrypted         = lookup(each.value, "encrypted", true)
  kms_key_id        = lookup(each.value, "kms_key_id", var.ebs_kms_key_id)

  tags = merge(
    local.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = "${var.name}-${each.key}"
    }
  )
}

resource "aws_volume_attachment" "additional" {
  for_each = var.create_instance && !var.create_autoscaling_group ? var.additional_ebs_volumes : {}

  device_name = each.value.device_name
  volume_id   = aws_ebs_volume.additional[each.key].id
  instance_id = aws_instance.this[0].id
}
