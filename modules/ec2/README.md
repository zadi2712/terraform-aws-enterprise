# EC2 Module

## Description

Enterprise-grade AWS EC2 module supporting standalone instances, Auto Scaling Groups, launch templates, and comprehensive monitoring.

## Features

- **Multiple Deployment Modes**: Standalone instances or Auto Scaling Groups
- **Launch Templates**: Modern instance configuration
- **Auto Scaling**: Target tracking and step scaling policies
- **IAM Integration**: Automatic instance profile creation
- **SSM Management**: AWS Systems Manager integration
- **CloudWatch Monitoring**: Detailed metrics and alarms
- **EBS Management**: Encrypted volumes with KMS
- **Elastic IPs**: Optional static IP addresses
- **IMDSv2**: Required by default for security
- **Warm Pools**: Faster scaling response
- **Instance Refresh**: Rolling updates support

## Resources Created

- `aws_instance` - EC2 instances (standalone mode)
- `aws_launch_template` - Launch template configuration
- `aws_autoscaling_group` - Auto Scaling Group
- `aws_autoscaling_policy` - Scaling policies
- `aws_autoscaling_schedule` - Scheduled scaling
- `aws_iam_role` - Instance IAM role
- `aws_iam_instance_profile` - Instance profile
- `aws_eip` - Elastic IP addresses
- `aws_ebs_volume` - Additional EBS volumes
- `aws_cloudwatch_metric_alarm` - CloudWatch alarms

## Usage

### Standalone Instance

```hcl
module "bastion" {
  source = "../../modules/ec2"

  name          = "bastion-host"
  instance_type = "t3.micro"
  ami_id        = "ami-0c55b159cbfafe1f0"

  # Network
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [module.bastion_sg.security_group_id]
  associate_public_ip_address = true

  # SSH key
  key_name = "my-key-pair"

  # IAM
  create_iam_instance_profile = true
  enable_ssm_management       = true

  # Storage
  root_volume_size      = 20
  root_volume_encrypted = true
  ebs_kms_key_id        = module.kms.key_arn

  # User data
  user_data = filebase64("${path.module}/user_data.sh")

  tags = {
    Environment = "production"
    Role        = "bastion"
  }
}
```

### Auto Scaling Group

```hcl
module "web_servers" {
  source = "../../modules/ec2"

  name          = "web-asg"
  instance_type = "t3.medium"
  ami_id        = data.aws_ami.amazon_linux_2023.id

  # Enable ASG mode
  create_autoscaling_group = true
  create_launch_template   = true

  # Network
  subnet_ids             = module.vpc.private_subnet_ids
  vpc_security_group_ids = [module.web_sg.security_group_id]

  # Auto Scaling
  min_size         = 2
  max_size         = 10
  desired_capacity = 4

  # Health checks
  health_check_type         = "ELB"
  health_check_grace_period = 300

  # Target groups
  target_group_arns = [module.alb.target_group_arns["web"]]

  # IAM
  create_iam_instance_profile = true
  enable_ssm_management       = true
  enable_cloudwatch_agent     = true

  # Storage
  block_device_mappings = [{
    device_name = "/dev/xvda"
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }]

  # Scaling policies
  target_tracking_policies = {
    cpu = {
      predefined_metric_type = "ASGAverageCPUUtilization"
      target_value           = 70
    }
  }

  # User data
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    environment  = "production"
    project_name = "myapp"
    application  = "web"
  }))

  tags = {
    Environment = "production"
    Application = "web-server"
  }
}
```

### Production ASG with All Features

```hcl
module "app_servers_prod" {
  source = "../../modules/ec2"

  name          = "prod-app"
  instance_type = "m5.large"
  ami_id        = var.golden_ami_id

  # ASG Configuration
  create_autoscaling_group = true
  create_launch_template   = true

  subnet_ids             = module.vpc.private_subnet_ids
  vpc_security_group_ids = [module.app_sg.security_group_id]

  # Capacity
  min_size         = 3
  max_size         = 20
  desired_capacity = 6

  # Health checks
  health_check_type         = "ELB"
  health_check_grace_period = 300

  # Target groups
  target_group_arns = [
    module.alb.target_group_arns["api"],
    module.alb.target_group_arns["app"]
  ]

  # IAM
  create_iam_instance_profile = true
  enable_ssm_management       = true
  enable_cloudwatch_agent     = true
  
  iam_role_policy_arns = {
    s3_access = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
    ecr_pull  = module.iam_policy.ecr_pull_policy_arn
  }

  # Storage
  block_device_mappings = [{
    device_name = "/dev/xvda"
    volume_size = 100
    volume_type = "gp3"
    iops        = 3000
    throughput  = 125
    encrypted   = true
    kms_key_id  = module.kms.key_arn
  }]

  # Monitoring
  enable_monitoring        = true
  create_cloudwatch_alarms = true
  cpu_high_threshold       = 75
  cpu_low_threshold        = 25
  alarm_actions            = [module.sns.topic_arn]

  # Scaling policies
  target_tracking_policies = {
    cpu = {
      predefined_metric_type = "ASGAverageCPUUtilization"
      target_value           = 70
    }
    
    network_in = {
      predefined_metric_type = "ASGAverageNetworkIn"
      target_value           = 10000000  # 10 MB
    }
  }

  # Scheduled scaling
  autoscaling_schedules = {
    scale_up_morning = {
      min_size         = 6
      max_size         = 20
      desired_capacity = 10
      recurrence       = "0 7 * * MON-FRI"
    }
    
    scale_down_evening = {
      min_size         = 3
      max_size         = 10
      desired_capacity = 4
      recurrence       = "0 19 * * MON-FRI"
    }
  }

  # Instance refresh
  instance_refresh_enabled               = true
  instance_refresh_min_healthy_percentage = 90

  # Warm pool for faster scaling
  warm_pool_enabled                   = true
  warm_pool_state                     = "Stopped"
  warm_pool_min_size                  = 2
  warm_pool_max_group_prepared_capacity = 10

  # Metadata
  require_imdsv2 = true

  tags = {
    Environment = "production"
    Application = "api-backend"
    ManagedBy   = "terraform"
  }
}
```

## Inputs

### Required

| Name | Description | Type |
|------|-------------|------|
| name | Name prefix for resources | string |

### Instance Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| create_instance | Create EC2 instance(s) | bool | `true` |
| instance_count | Number of standalone instances | number | `1` |
| ami_id | AMI ID to use | string | `null` |
| instance_type | Instance type | string | `"t3.medium"` |
| key_name | SSH key pair name | string | `null` |
| ignore_ami_changes | Ignore AMI changes in lifecycle | bool | `false` |

### Auto Scaling

| Name | Description | Type | Default |
|------|-------------|------|---------|
| create_autoscaling_group | Create Auto Scaling Group | bool | `false` |
| min_size | Minimum instances in ASG | number | `1` |
| max_size | Maximum instances in ASG | number | `3` |
| desired_capacity | Desired instances in ASG | number | `2` |
| health_check_type | Health check type (EC2/ELB) | string | `"EC2"` |
| health_check_grace_period | Grace period for health checks | number | `300` |

### Storage

| Name | Description | Type | Default |
|------|-------------|------|---------|
| root_volume_size | Root volume size (GB) | number | `30` |
| root_volume_type | Root volume type | string | `"gp3"` |
| root_volume_encrypted | Encrypt root volume | bool | `true` |
| ebs_kms_key_id | KMS key for EBS encryption | string | `null` |
| ebs_block_devices | Additional EBS volumes | list(object) | `[]` |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | Instance ID (first instance) |
| instance_ids | All instance IDs |
| private_ip | Private IP (first instance) |
| private_ips | All private IPs |
| public_ip | Public IP (first instance) |
| autoscaling_group_name | ASG name |
| autoscaling_group_arn | ASG ARN |
| iam_role_arn | IAM role ARN |
| launch_template_id | Launch template ID |
| ec2_info | Complete instance information |

## Deployment Modes

### Mode 1: Standalone Instance

Best for:
- Bastion hosts
- Jump boxes
- Single-purpose servers
- Development instances

```hcl
create_instance          = true
create_autoscaling_group = false
instance_count           = 1
```

### Mode 2: Multiple Standalone Instances

Best for:
- Small clusters without load balancing
- Test environments

```hcl
create_instance          = true
create_autoscaling_group = false
instance_count           = 3
subnet_ids               = [subnet-a, subnet-b, subnet-c]
```

### Mode 3: Auto Scaling Group

Best for:
- Web servers
- Application servers
- Scalable workloads
- Production environments

```hcl
create_instance          = false
create_autoscaling_group = true
create_launch_template   = true

min_size         = 2
max_size         = 10
desired_capacity = 4
```

## Scaling Strategies

### Target Tracking (Recommended)

Automatically maintains target metric:

```hcl
target_tracking_policies = {
  cpu = {
    predefined_metric_type = "ASGAverageCPUUtilization"
    target_value           = 70
  }
}
```

### Step Scaling

More control over scaling increments:

```hcl
step_scaling_policies = {
  scale_up = {
    adjustment_type = "ChangeInCapacity"
    step_adjustments = [
      {
        scaling_adjustment          = 1
        metric_interval_lower_bound = 0
        metric_interval_upper_bound = 10
      },
      {
        scaling_adjustment          = 2
        metric_interval_lower_bound = 10
      }
    ]
  }
}
```

### Scheduled Scaling

Scale based on time:

```hcl
autoscaling_schedules = {
  business_hours_start = {
    min_size         = 5
    max_size         = 20
    desired_capacity = 10
    recurrence       = "0 7 * * MON-FRI"
  }
  
  business_hours_end = {
    min_size         = 2
    max_size         = 5
    desired_capacity = 3
    recurrence       = "0 19 * * MON-FRI"
  }
}
```

## IAM Permissions

The module can create an IAM instance profile with:

### Default Permissions

- **SSM Management**: `AmazonSSMManagedInstanceCore` (if enabled)
- **CloudWatch Agent**: `CloudWatchAgentServerPolicy` (if enabled)

### Custom Permissions

```hcl
iam_role_policy_arns = {
  s3_access = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ecr_pull  = "arn:aws:iam::123456789012:policy/ECRPullPolicy"
}
```

## Storage Options

### Root Volume

```hcl
root_volume_size      = 50
root_volume_type      = "gp3"
root_volume_iops      = 3000
root_volume_throughput = 125
root_volume_encrypted = true
ebs_kms_key_id        = module.kms.key_arn
```

### Additional Volumes

```hcl
ebs_block_devices = [{
  device_name = "/dev/sdf"
  volume_size = 100
  volume_type = "gp3"
  encrypted   = true
}]
```

### Volume Types

- **gp3** - General Purpose SSD (default, best price/performance)
- **gp2** - General Purpose SSD (previous generation)
- **io1/io2** - Provisioned IOPS SSD (high performance)
- **st1** - Throughput Optimized HDD
- **sc1** - Cold HDD

## User Data

### Using Template File

```hcl
user_data = base64encode(templatefile("${path.module}/user_data.sh", {
  environment  = "production"
  project_name = "myapp"
  application  = "web"
}))
```

### Inline Script

```hcl
user_data = base64encode(<<-EOF
  #!/bin/bash
  yum update -y
  yum install -y httpd
  systemctl start httpd
  systemctl enable httpd
  echo "Hello World" > /var/www/html/index.html
EOF
)
```

## Security Best Practices

### 1. Use IMDSv2

```hcl
require_imdsv2 = true  # Default
```

### 2. Encrypt EBS Volumes

```hcl
root_volume_encrypted = true
ebs_kms_key_id        = module.kms.key_arn
```

### 3. Use SSM Instead of SSH

```hcl
enable_ssm_management = true
# No need for SSH key or bastion host
```

### 4. Disable Public IP in Production

```hcl
associate_public_ip_address = false
# Use private subnets
```

### 5. Use Security Groups

```hcl
vpc_security_group_ids = [
  module.app_sg.security_group_id
]
```

## Monitoring

### CloudWatch Metrics

Enabled by default:
- CPU Utilization
- Disk I/O
- Network I/O
- Status checks

### Custom Metrics (with CloudWatch Agent)

```hcl
enable_cloudwatch_agent = true
```

Provides:
- Memory utilization
- Disk space utilization
- Custom application metrics

### Alarms

```hcl
create_cloudwatch_alarms = true
cpu_high_threshold       = 80
cpu_low_threshold        = 20
alarm_actions            = [module.sns.topic_arn]
```

## Instance Types

### General Purpose
- **t3/t4g**: Burstable (2-8 vCPU, 0.5-32 GB RAM)
- **m5/m6i**: Balanced (2-96 vCPU, 8-384 GB RAM)

### Compute Optimized
- **c5/c6i**: High CPU (2-96 vCPU, 4-192 GB RAM)

### Memory Optimized
- **r5/r6i**: High memory (2-96 vCPU, 16-768 GB RAM)

### Storage Optimized
- **i3/i4i**: High IOPS (2-64 vCPU, 15-512 GB RAM)

## Best Practices

### 1. Use Launch Templates

```hcl
create_launch_template = true
```

Benefits:
- Versioning
- Faster instance launches
- Required for mixed instance policies

### 2. Enable Instance Refresh

```hcl
instance_refresh_enabled               = true
instance_refresh_min_healthy_percentage = 90
```

Benefits:
- Rolling updates
- Zero downtime deployments
- Automatic AMI updates

### 3. Use Warm Pools

```hcl
warm_pool_enabled = true
warm_pool_state   = "Stopped"
warm_pool_min_size = 2
```

Benefits:
- Faster scale-out
- Lower costs (stopped instances)
- Better response to traffic spikes

### 4. Configure Termination Policies

```hcl
termination_policies = [
  "OldestLaunchTemplate",
  "OldestInstance"
]
```

Options:
- `OldestInstance`
- `NewestInstance`
- `OldestLaunchTemplate`
- `AllocationStrategy`
- `Default`

### 5. Use Target Tracking

```hcl
target_tracking_policies = {
  cpu = {
    predefined_metric_type = "ASGAverageCPUUtilization"
    target_value           = 70
  }
}
```

Simpler and more effective than step scaling.

## Examples

### Bastion Host

```hcl
module "bastion" {
  source = "../../modules/ec2"

  name          = "bastion"
  instance_type = "t3.micro"
  ami_id        = data.aws_ami.amazon_linux.id

  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [module.bastion_sg.id]
  associate_public_ip_address = true
  allocate_eip                = true

  key_name = "bastion-key"

  create_iam_instance_profile = true
  enable_ssm_management       = true

  tags = {
    Role = "bastion"
  }
}
```

### Application Server Cluster

```hcl
module "app_cluster" {
  source = "../../modules/ec2"

  name = "app-cluster"
  
  create_autoscaling_group = true
  create_launch_template   = true

  instance_type = "m5.xlarge"
  ami_id        = var.app_ami_id

  subnet_ids = module.vpc.private_subnet_ids
  vpc_security_group_ids = [module.app_sg.id]

  min_size         = 3
  max_size         = 15
  desired_capacity = 6

  target_group_arns = [module.alb.target_group_arn]

  create_iam_instance_profile = true
  enable_ssm_management       = true

  target_tracking_policies = {
    cpu = {
      predefined_metric_type = "ASGAverageCPUUtilization"
      target_value           = 70
    }
  }

  tags = {
    Application = "backend"
  }
}
```

## Troubleshooting

### Instances Not Launching

```bash
# Check launch template
aws ec2 describe-launch-template-versions \
  --launch-template-id lt-xxxxx

# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names my-asg

# Check recent activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name my-asg \
  --max-records 10
```

### Health Checks Failing

```bash
# Describe instances
aws autoscaling describe-auto-scaling-instances

# Check instance health
aws ec2 describe-instance-status \
  --instance-ids i-xxxxx
```

### User Data Not Running

```bash
# Connect via SSM
aws ssm start-session --target i-xxxxx

# Check user data log
sudo cat /var/log/user-data.log
sudo cat /var/log/cloud-init-output.log
```

## References

- [EC2 User Guide](https://docs.aws.amazon.com/ec2/)
- [Auto Scaling User Guide](https://docs.aws.amazon.com/autoscaling/)
- [Launch Templates](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-launch-templates.html)
- [IMDSv2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html)

## Related Modules

- [Security Group Module](../security-group/README.md)
- [ALB Module](../alb/README.md)
- [VPC Module](../vpc/README.md)
- [IAM Module](../iam/README.md)
