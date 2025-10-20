# EC2 Deployment Guide

## Overview

Complete guide for deploying and managing AWS EC2 instances and Auto Scaling Groups using the enterprise Terraform EC2 module.

**Version:** 2.0  
**Last Updated:** October 20, 2025  
**Status:** ✅ Production Ready

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Deployment Modes](#deployment-modes)
4. [Deployment Steps](#deployment-steps)
5. [Configuration Guide](#configuration-guide)
6. [Scaling Strategies](#scaling-strategies)
7. [Security Best Practices](#security-best-practices)
8. [Monitoring](#monitoring)
9. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### EC2 Module Capabilities

```
┌────────────────────────────────────────────────────────────┐
│                    EC2 Module                               │
│                                                              │
│  ┌──────────────────┐         ┌──────────────────────┐    │
│  │ Standalone Mode  │         │  Auto Scaling Mode   │    │
│  │                  │         │                      │    │
│  │ • Single/Multi   │         │ • Launch Template    │    │
│  │   Instances      │         │ • ASG                │    │
│  │ • Elastic IPs    │         │ • Scaling Policies   │    │
│  │ • Static Config  │         │ • Scheduled Scaling  │    │
│  └──────────────────┘         │ • Warm Pools         │    │
│                                │ • Instance Refresh   │    │
│                                └──────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐   │
│  │           Common Features                           │   │
│  │  • IAM Instance Profiles                           │   │
│  │  • SSM Session Manager                             │   │
│  │  • CloudWatch Monitoring                           │   │
│  │  • EBS Encryption (KMS)                            │   │
│  │  • IMDSv2 Required                                 │   │
│  │  • User Data Scripts                               │   │
│  └────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Required Infrastructure

1. **VPC** - Deployed networking layer
2. **Security Groups** - Network access rules
3. **KMS Keys** (optional) - For EBS encryption
4. **SNS Topics** (optional) - For alarm notifications

### Required Information

- **AMI ID** - Amazon Machine Image to use
- **SSH Key Pair** - For SSH access (or use SSM)
- **Subnet IDs** - Where to deploy instances
- **Security Group IDs** - Network access control

### Tools Required

- Terraform >= 1.13.0
- AWS CLI v2
- SSH client (optional if using SSM)

---

## Deployment Modes

### Mode 1: Bastion Host (Standalone)

**Use Case:** SSH jump server, management instance

```hcl
module "bastion" {
  source = "../../modules/ec2"

  name          = "bastion"
  instance_type = "t3.micro"
  ami_id        = data.aws_ami.amazon_linux.id

  # Standalone mode
  create_instance = true
  instance_count  = 1

  # Public subnet with EIP
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  allocate_eip                = true

  # SSH access
  key_name = "bastion-key"
  vpc_security_group_ids = [module.bastion_sg.id]

  # SSM for secure access
  create_iam_instance_profile = true
  enable_ssm_management       = true

  tags = {
    Role = "bastion"
  }
}
```

### Mode 2: Web Server ASG

**Use Case:** Scalable web application servers

```hcl
module "web_asg" {
  source = "../../modules/ec2"

  name          = "web"
  instance_type = "t3.medium"
  ami_id        = var.web_ami_id

  # ASG mode
  create_autoscaling_group = true
  create_launch_template   = true

  # Private subnets
  subnet_ids             = module.vpc.private_subnet_ids
  vpc_security_group_ids = [module.web_sg.id]

  # Capacity
  min_size         = 2
  max_size         = 10
  desired_capacity = 4

  # Load balancer integration
  health_check_type = "ELB"
  target_group_arns = [module.alb.target_group_arns["web"]]

  # Auto scaling
  target_tracking_policies = {
    cpu = {
      predefined_metric_type = "ASGAverageCPUUtilization"
      target_value           = 70
    }
  }

  # IAM and management
  create_iam_instance_profile = true
  enable_ssm_management       = true
  enable_cloudwatch_agent     = true

  tags = {
    Application = "web-server"
  }
}
```

### Mode 3: Application Cluster

**Use Case:** Application servers with advanced scaling

```hcl
module "app_cluster" {
  source = "../../modules/ec2"

  name          = "app"
  instance_type = "m5.large"
  ami_id        = var.app_ami_id

  create_autoscaling_group = true
  create_launch_template   = true

  subnet_ids             = module.vpc.private_subnet_ids
  vpc_security_group_ids = [module.app_sg.id]

  min_size         = 3
  max_size         = 20
  desired_capacity = 6

  # Advanced features
  instance_refresh_enabled = true
  warm_pool_enabled        = true
  warm_pool_min_size       = 2

  # Multiple scaling policies
  target_tracking_policies = {
    cpu = {
      predefined_metric_type = "ASGAverageCPUUtilization"
      target_value           = 70
    }
    
    network = {
      predefined_metric_type = "ASGAverageNetworkIn"
      target_value           = 10000000
    }
  }

  # Scheduled scaling
  autoscaling_schedules = {
    scale_up = {
      desired_capacity = 10
      recurrence       = "0 7 * * MON-FRI"
    }
  }

  tags = {
    Application = "backend"
  }
}
```

---

## Deployment Steps

### Step 1: Prepare AMI

```bash
# Find Amazon Linux 2023 AMI
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-*" \
          "Name=architecture,Values=x86_64" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text

# Or use data source in Terraform
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
```

### Step 2: Create SSH Key Pair

```bash
# Create key pair
aws ec2 create-key-pair \
  --key-name bastion-prod-key \
  --query 'KeyMaterial' \
  --output text > bastion-prod-key.pem

chmod 400 bastion-prod-key.pem
```

### Step 3: Configure Variables

Edit `terraform.tfvars`:

```hcl
# Enable bastion
enable_bastion = true

# Configure bastion
bastion_instance_type       = "t3.micro"
bastion_ami_id              = "ami-xxxxx"  # From step 1
bastion_key_name            = "bastion-prod-key"
bastion_allowed_cidrs       = ["203.0.113.0/24"]  # Your office IP
bastion_allocate_eip        = true
bastion_root_volume_size    = 20
```

### Step 4: Deploy

```bash
cd layers/compute/environments/dev
terraform init -backend-config=backend.conf
terraform plan
terraform apply
```

### Step 5: Connect to Instance

#### Option A: SSH (if key pair configured)

```bash
# Get bastion public IP
BASTION_IP=$(terraform output -raw bastion_eip)

# Connect
ssh -i bastion-prod-key.pem ec2-user@$BASTION_IP
```

#### Option B: SSM Session Manager (Recommended)

```bash
# Get instance ID
INSTANCE_ID=$(terraform output -raw bastion_instance_id)

# Connect via SSM (no SSH key needed!)
aws ssm start-session --target $INSTANCE_ID
```

---

## Configuration Guide

### AMI Selection

#### Amazon Linux 2023 (Recommended)

```hcl
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }
}

ami_id = data.aws_ami.amazon_linux_2023.id
```

#### Ubuntu 22.04 LTS

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

ami_id = data.aws_ami.ubuntu.id
```

### Instance Sizing

| Workload | Instance Type | vCPU | Memory | Use Case |
|----------|--------------|------|--------|----------|
| **Minimal** | t3.micro | 2 | 1 GB | Bastion, dev |
| **Small** | t3.small | 2 | 2 GB | Small apps |
| **Medium** | t3.medium | 2 | 4 GB | Web servers |
| **Large** | m5.large | 2 | 8 GB | Applications |
| **XLarge** | m5.xlarge | 4 | 16 GB | Heavy workloads |

### Storage Configuration

#### Root Volume

```hcl
root_volume_size      = 30
root_volume_type      = "gp3"  # Best price/performance
root_volume_encrypted = true
ebs_kms_key_id        = module.kms.key_arn
```

#### Additional Volumes

```hcl
ebs_block_devices = [
  {
    device_name = "/dev/sdf"
    volume_size = 100
    volume_type = "gp3"
    encrypted   = true
  },
  {
    device_name = "/dev/sdg"
    volume_size = 500
    volume_type = "st1"  # Throughput optimized for data
    encrypted   = true
  }
]
```

### IAM Configuration

#### Basic SSM Access

```hcl
create_iam_instance_profile = true
enable_ssm_management       = true
```

#### With CloudWatch Agent

```hcl
create_iam_instance_profile = true
enable_ssm_management       = true
enable_cloudwatch_agent     = true
```

#### With Custom Policies

```hcl
create_iam_instance_profile = true
enable_ssm_management       = true

iam_role_policy_arns = {
  s3_access = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ecr_pull  = module.iam_policy.ecr_pull_arn
  dynamodb  = module.iam_policy.dynamodb_read_arn
}
```

---

## Scaling Strategies

### Target Tracking Scaling (Recommended)

Automatically maintains target metric value:

```hcl
target_tracking_policies = {
  cpu = {
    predefined_metric_type = "ASGAverageCPUUtilization"
    target_value           = 70  # Maintain 70% CPU
  }
  
  network_in = {
    predefined_metric_type = "ASGAverageNetworkIn"
    target_value           = 10000000  # 10 MB/s
  }
}
```

**Predefined Metrics:**
- `ASGAverageCPUUtilization`
- `ASGAverageNetworkIn`
- `ASGAverageNetworkOut`
- `ALBRequestCountPerTarget`

### Step Scaling

More control over scaling increments:

```hcl
step_scaling_policies = {
  scale_up = {
    adjustment_type = "ChangeInCapacity"
    step_adjustments = [
      {
        scaling_adjustment          = 1  # Add 1 instance
        metric_interval_lower_bound = 0
        metric_interval_upper_bound = 10
      },
      {
        scaling_adjustment          = 2  # Add 2 instances
        metric_interval_lower_bound = 10
        metric_interval_upper_bound = 20
      },
      {
        scaling_adjustment          = 3  # Add 3 instances
        metric_interval_lower_bound = 20
      }
    ]
  }
}
```

### Scheduled Scaling

Scale based on predictable patterns:

```hcl
autoscaling_schedules = {
  # Scale up for business hours
  business_hours_start = {
    min_size         = 5
    max_size         = 20
    desired_capacity = 10
    recurrence       = "0 7 * * MON-FRI"  # 7 AM weekdays
  }
  
  # Scale down after business hours
  business_hours_end = {
    min_size         = 2
    max_size         = 5
    desired_capacity = 3
    recurrence       = "0 19 * * MON-FRI"  # 7 PM weekdays
  }
  
  # Minimal capacity on weekends
  weekend_scale_down = {
    min_size         = 1
    max_size         = 3
    desired_capacity = 2
    recurrence       = "0 0 * * SAT"  # Midnight Saturday
  }
}
```

---

## Security Best Practices

### 1. Use SSM Instead of SSH

**Traditional SSH:**
```hcl
# ❌ Requires bastion, key management, open ports
key_name = "my-key"
```

**SSM Session Manager:**
```hcl
# ✅ No SSH keys, no open ports, full audit trail
create_iam_instance_profile = true
enable_ssm_management       = true
```

Connect:
```bash
aws ssm start-session --target i-xxxxx
```

### 2. Require IMDSv2

```hcl
require_imdsv2 = true  # Default
```

Prevents SSRF attacks on metadata service.

### 3. Encrypt EBS Volumes

```hcl
root_volume_encrypted = true
ebs_kms_key_id        = data.terraform_remote_state.security.outputs.kms_ebs_key_arn
```

### 4. Use Private Subnets

```hcl
subnet_ids = module.vpc.private_subnet_ids  # ✅
# Not public_subnet_ids (except for bastion)
```

### 5. Minimal IAM Permissions

```hcl
# Only attach necessary policies
iam_role_policy_arns = {
  s3_read = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  # Don't use Administrator or PowerUser
}
```

---

## Instance Refresh

Enable zero-downtime updates:

```hcl
instance_refresh_enabled               = true
instance_refresh_min_healthy_percentage = 90
instance_refresh_instance_warmup       = 300
```

**How it works:**
1. New launch template version created
2. ASG gradually replaces instances
3. Maintains minimum healthy percentage
4. Waits for instance warmup before continuing

**Usage:**
```bash
# Update AMI in terraform.tfvars
ami_id = "ami-new-version"

# Apply (triggers instance refresh automatically)
terraform apply
```

---

## Warm Pools

Pre-initialize instances for faster scaling:

```hcl
warm_pool_enabled                   = true
warm_pool_state                     = "Stopped"  # Save costs
warm_pool_min_size                  = 2
warm_pool_max_group_prepared_capacity = 10
```

**Benefits:**
- Faster scale-out (30-60 seconds vs 2-3 minutes)
- Lower costs (stopped instances)
- Better handling of traffic spikes

**States:**
- **Stopped** - Cheapest, ~40s to running
- **Running** - Fastest, full EC2 cost
- **Hibernated** - Medium speed/cost

---

## Monitoring

### CloudWatch Metrics (Default)

- CPU Utilization
- Network In/Out
- Disk Read/Write
- Status Check Failed

### Enhanced Monitoring

```hcl
enable_cloudwatch_agent = true
```

Provides:
- Memory utilization
- Disk space usage
- Per-process metrics

### CloudWatch Alarms

```hcl
create_cloudwatch_alarms = true
cpu_high_threshold       = 80
cpu_low_threshold        = 20
alarm_actions            = [module.sns.alerts_topic_arn]
```

Creates:
- CPU high alarm (for scale-up awareness)
- CPU low alarm (for scale-down awareness)

---

## User Data Scripts

### Using Provided Template

```hcl
user_data = base64encode(templatefile("${path.module}/../../modules/ec2/user_data.sh", {
  environment  = "production"
  project_name = "myapp"
  application  = "web"
}))
```

### Custom User Data

```hcl
user_data = base64encode(<<-EOF
  #!/bin/bash
  set -e
  
  # Update system
  yum update -y
  
  # Install application
  yum install -y httpd
  systemctl start httpd
  systemctl enable httpd
  
  # Configure application
  echo "Hello from ${var.environment}" > /var/www/html/index.html
EOF
)
```

### Debugging User Data

```bash
# Connect to instance
aws ssm start-session --target i-xxxxx

# Check user data execution
sudo cat /var/log/user-data.log
sudo cat /var/log/cloud-init-output.log

# Check status
cloud-init status
```

---

## Load Balancer Integration

### With Application Load Balancer

```hcl
# 1. Create target group
resource "aws_lb_target_group" "app" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  
  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# 2. Attach to ASG
module "app_asg" {
  source = "../../modules/ec2"
  # ... other config ...
  
  target_group_arns = [aws_lb_target_group.app.arn]
  health_check_type = "ELB"  # Use ALB health checks
}
```

---

## Best Practices

### 1. Use Latest Generation Instances

```hcl
# ✅ Good
instance_type = "m6i.large"  # Latest generation

# ❌ Avoid
instance_type = "m3.large"   # Old generation
```

### 2. Enable EBS Optimization

```hcl
ebs_optimized = true  # Default in module
```

### 3. Use gp3 Volumes

```hcl
root_volume_type = "gp3"  # 20% cheaper than gp2, better performance
```

### 4. Set Termination Protection (Production)

```hcl
termination_policies = [
  "OldestLaunchTemplate",  # Terminate outdated instances first
  "OldestInstance"
]
```

### 5. Use Multiple AZs

```hcl
subnet_ids = [
  module.vpc.private_subnets[0],  # us-east-1a
  module.vpc.private_subnets[1],  # us-east-1b
  module.vpc.private_subnets[2]   # us-east-1c
]
```

---

## Troubleshooting

### Issue: Instances Not Launching

**Check ASG Status:**
```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names myapp-prod-asg

# Check recent activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name myapp-prod-asg \
  --max-records 10
```

**Common Causes:**
- Insufficient capacity in AZ
- AMI not available
- Subnet has no available IPs
- IAM permissions missing

### Issue: Health Checks Failing

**Check Instance Health:**
```bash
aws ec2 describe-instance-status \
  --instance-ids i-xxxxx

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:...
```

**Common Causes:**
- Application not responding on health check port
- Security groups blocking ALB health checks
- Instance not ready (increase grace period)

### Issue: User Data Not Running

**Debug:**
```bash
# Connect via SSM
aws ssm start-session --target i-xxxxx

# Check logs
sudo cat /var/log/user-data.log
sudo cat /var/log/cloud-init-output.log

# Check cloud-init status
cloud-init status --long
```

### Issue: Cannot Connect via SSM

**Verify:**
```bash
# Check IAM instance profile
aws ec2 describe-instances \
  --instance-ids i-xxxxx \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'

# Check SSM agent status
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=i-xxxxx"
```

**Common Causes:**
- IAM instance profile missing
- SSM agent not running
- No internet connectivity (needs NAT Gateway or VPC endpoints)

---

## Cost Optimization

### 1. Use Appropriate Instance Types

```hcl
# Development
instance_type = "t3.micro"    # $0.0104/hour

# Production
instance_type = "t3.medium"   # $0.0416/hour
```

### 2. Use Spot Instances (ASG)

```hcl
# In launch template
instance_market_options {
  market_type = "spot"
  
  spot_options {
    max_price = "0.05"  # Up to 90% discount
  }
}
```

### 3. Schedule Scaling

```hcl
# Scale down during off-hours
autoscaling_schedules = {
  evening = {
    desired_capacity = 2  # Minimum capacity
    recurrence       = "0 19 * * *"
  }
}
```

### 4. Use Warm Pool

```hcl
warm_pool_enabled = true
warm_pool_state   = "Stopped"  # Pay only for EBS
```

---

## References

- [EC2 Module README](modules/ec2/README.md)
- [AWS EC2 User Guide](https://docs.aws.amazon.com/ec2/)
- [Auto Scaling Guide](https://docs.aws.amazon.com/autoscaling/)
- [SSM Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)

---

**End of Deployment Guide**

