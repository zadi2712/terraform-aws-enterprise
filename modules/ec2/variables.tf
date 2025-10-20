################################################################################
# EC2 Module - Variables
# Version: 2.0
################################################################################

################################################################################
# Required Variables
################################################################################

variable "name" {
  description = "Name prefix for EC2 resources"
  type        = string
}

################################################################################
# Instance Configuration
################################################################################

variable "create_instance" {
  description = "Whether to create EC2 instance(s)"
  type        = bool
  default     = true
}

variable "instance_count" {
  description = "Number of instances to create (for standalone instances)"
  type        = number
  default     = 1
}

variable "ami_id" {
  description = "AMI ID to use for the instance(s)"
  type        = string
  default     = null
}

variable "instance_type" {
  description = "Instance type to use"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = null
}

variable "ignore_ami_changes" {
  description = "Whether to ignore AMI changes in lifecycle"
  type        = bool
  default     = false
}

################################################################################
# Network Configuration
################################################################################

variable "subnet_id" {
  description = "Subnet ID for standalone instance"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "List of subnet IDs for Auto Scaling Group or multiple instances"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
  default     = []
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP address"
  type        = bool
  default     = null
}

variable "availability_zone" {
  description = "Availability zone for standalone instance"
  type        = string
  default     = null
}

################################################################################
# IAM Configuration
################################################################################

variable "create_iam_instance_profile" {
  description = "Whether to create IAM instance profile"
  type        = bool
  default     = false
}

variable "iam_instance_profile_name" {
  description = "Name of existing IAM instance profile to use"
  type        = string
  default     = null
}

variable "enable_ssm_management" {
  description = "Enable AWS Systems Manager for instance management"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_agent" {
  description = "Enable CloudWatch agent permissions"
  type        = bool
  default     = true
}

variable "iam_role_policy_arns" {
  description = "Map of additional IAM policy ARNs to attach to instance role"
  type        = map(string)
  default     = {}
}

################################################################################
# Launch Template Configuration
################################################################################

variable "create_launch_template" {
  description = "Whether to create launch template"
  type        = bool
  default     = false
}

variable "launch_template_id" {
  description = "ID of existing launch template to use"
  type        = string
  default     = null
}

variable "launch_template_version" {
  description = "Launch template version to use"
  type        = string
  default     = "$Latest"
}

################################################################################
# User Data Configuration
################################################################################

variable "user_data" {
  description = "User data script (will be base64 encoded)"
  type        = string
  default     = null
}

variable "user_data_base64" {
  description = "User data script already base64 encoded"
  type        = string
  default     = null
}

variable "user_data_replace_on_change" {
  description = "Replace instance when user data changes"
  type        = bool
  default     = false
}

################################################################################
# Storage Configuration
################################################################################

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "Type of root volume (gp3, gp2, io1, io2)"
  type        = string
  default     = "gp3"
}

variable "root_volume_iops" {
  description = "IOPS for root volume (io1/io2/gp3)"
  type        = number
  default     = null
}

variable "root_volume_throughput" {
  description = "Throughput for root volume in MB/s (gp3 only)"
  type        = number
  default     = null
}

variable "root_delete_on_termination" {
  description = "Whether to delete root volume on instance termination"
  type        = bool
  default     = true
}

variable "root_volume_encrypted" {
  description = "Whether to encrypt root volume"
  type        = bool
  default     = true
}

variable "ebs_kms_key_id" {
  description = "KMS key ID for EBS encryption"
  type        = string
  default     = null
}

variable "ebs_optimized" {
  description = "Whether to enable EBS optimization"
  type        = bool
  default     = true
}

variable "ebs_block_devices" {
  description = "Additional EBS block devices"
  type = list(object({
    device_name           = string
    volume_size           = optional(number, 50)
    volume_type           = optional(string, "gp3")
    iops                  = optional(number)
    throughput            = optional(number)
    delete_on_termination = optional(bool, true)
    encrypted             = optional(bool, true)
    kms_key_id            = optional(string)
  }))
  default = []
}

variable "additional_ebs_volumes" {
  description = "Additional EBS volumes to create and attach"
  type = map(object({
    device_name = string
    size        = number
    type        = optional(string, "gp3")
    iops        = optional(number)
    throughput  = optional(number)
    encrypted   = optional(bool, true)
    kms_key_id  = optional(string)
    tags        = optional(map(string), {})
  }))
  default = {}
}

variable "block_device_mappings" {
  description = "Block device mappings for launch template"
  type = list(object({
    device_name           = string
    volume_size           = optional(number, 30)
    volume_type           = optional(string, "gp3")
    iops                  = optional(number)
    throughput            = optional(number)
    delete_on_termination = optional(bool, true)
    encrypted             = optional(bool, true)
    kms_key_id            = optional(string)
  }))
  default = []
}

################################################################################
# Auto Scaling Group Configuration
################################################################################

variable "create_autoscaling_group" {
  description = "Whether to create Auto Scaling Group"
  type        = bool
  default     = false
}

variable "min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 2
}

variable "health_check_type" {
  description = "Type of health check (EC2 or ELB)"
  type        = string
  default     = "EC2"
}

variable "health_check_grace_period" {
  description = "Time after instance launch before health checks start"
  type        = number
  default     = 300
}

variable "default_cooldown" {
  description = "Amount of time after scaling activity before another can occur"
  type        = number
  default     = 300
}

variable "termination_policies" {
  description = "List of policies to decide which instances to terminate"
  type        = list(string)
  default     = ["Default"]
}

variable "suspended_processes" {
  description = "List of processes to suspend for the ASG"
  type        = list(string)
  default     = []
}

variable "enabled_metrics" {
  description = "List of metrics to collect"
  type        = list(string)
  default = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances"
  ]
}

variable "metrics_granularity" {
  description = "Granularity to associate with metrics"
  type        = string
  default     = "1Minute"
}

variable "target_group_arns" {
  description = "List of ALB/NLB target group ARNs"
  type        = list(string)
  default     = []
}

################################################################################
# Auto Scaling Policies
################################################################################

variable "target_tracking_policies" {
  description = "Map of target tracking scaling policies"
  type = map(object({
    predefined_metric_type = string
    target_value           = number
    resource_label         = optional(string)
    disable_scale_in       = optional(bool, false)
  }))
  default = {}
}

variable "step_scaling_policies" {
  description = "Map of step scaling policies"
  type = map(object({
    adjustment_type = string
    step_adjustments = list(object({
      scaling_adjustment          = number
      metric_interval_lower_bound = optional(number)
      metric_interval_upper_bound = optional(number)
    }))
    metric_aggregation_type = optional(string, "Average")
  }))
  default = {}
}

variable "autoscaling_schedules" {
  description = "Map of Auto Scaling schedules"
  type = map(object({
    min_size         = optional(number)
    max_size         = optional(number)
    desired_capacity = optional(number)
    recurrence       = optional(string)
    start_time       = optional(string)
    end_time         = optional(string)
  }))
  default = {}
}

################################################################################
# Instance Refresh
################################################################################

variable "instance_refresh_enabled" {
  description = "Enable instance refresh for rolling updates"
  type        = bool
  default     = false
}

variable "instance_refresh_min_healthy_percentage" {
  description = "Minimum healthy percentage during instance refresh"
  type        = number
  default     = 90
}

variable "instance_refresh_instance_warmup" {
  description = "Instance warmup time during refresh"
  type        = number
  default     = 300
}

################################################################################
# Warm Pool Configuration
################################################################################

variable "warm_pool_enabled" {
  description = "Enable warm pool for faster scaling"
  type        = bool
  default     = false
}

variable "warm_pool_state" {
  description = "Warm pool instance state (Stopped, Running, Hibernated)"
  type        = string
  default     = "Stopped"
}

variable "warm_pool_min_size" {
  description = "Minimum number of instances in warm pool"
  type        = number
  default     = 0
}

variable "warm_pool_max_group_prepared_capacity" {
  description = "Maximum prepared capacity (instances + warm pool)"
  type        = number
  default     = null
}

################################################################################
# Monitoring Configuration
################################################################################

variable "enable_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "create_cloudwatch_alarms" {
  description = "Create CloudWatch alarms for ASG"
  type        = bool
  default     = false
}

variable "cpu_high_threshold" {
  description = "CPU threshold for scale-up alarm"
  type        = number
  default     = 80
}

variable "cpu_low_threshold" {
  description = "CPU threshold for scale-down alarm"
  type        = number
  default     = 20
}

variable "alarm_actions" {
  description = "List of alarm actions (SNS topic ARNs)"
  type        = list(string)
  default     = []
}

################################################################################
# Metadata Configuration
################################################################################

variable "require_imdsv2" {
  description = "Require IMDSv2 for instance metadata"
  type        = bool
  default     = true
}

variable "enable_instance_metadata_tags" {
  description = "Enable instance tags in metadata"
  type        = bool
  default     = false
}

################################################################################
# T-Series Instance Configuration
################################################################################

variable "cpu_credits" {
  description = "Credit option for T instances (standard or unlimited)"
  type        = string
  default     = "standard"
  
  validation {
    condition     = contains(["standard", "unlimited"], var.cpu_credits)
    error_message = "cpu_credits must be 'standard' or 'unlimited'"
  }
}

################################################################################
# Elastic IP Configuration
################################################################################

variable "allocate_eip" {
  description = "Allocate Elastic IP for instance(s)"
  type        = bool
  default     = false
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
