# EC2 Quick Reference

## 🚀 Quick Start

### Deploy Bastion Host

```bash
cd layers/compute/environments/dev

# Edit terraform.tfvars
enable_bastion = true
bastion_key_name = "my-key-pair"

# Deploy
terraform init -backend-config=backend.conf
terraform apply

# Get outputs
terraform output bastion_eip
terraform output bastion_instance_id
```

### Connect to Instance

```bash
# Option 1: SSM (Recommended - No SSH key needed)
aws ssm start-session --target $(terraform output -raw bastion_instance_id)

# Option 2: SSH
ssh -i my-key.pem ec2-user@$(terraform output -raw bastion_eip)
```

---

## 📋 Common Commands

### AWS CLI - Instances

```bash
# List instances
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=production" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress,PublicIpAddress]' \
  --output table

# Start instance
aws ec2 start-instances --instance-ids i-xxxxx

# Stop instance
aws ec2 stop-instances --instance-ids i-xxxxx

# Reboot instance
aws ec2 reboot-instances --instance-ids i-xxxxx

# Terminate instance
aws ec2 terminate-instances --instance-ids i-xxxxx

# Get instance console output
aws ec2 get-console-output --instance-id i-xxxxx

# Get instance screenshot
aws ec2 get-console-screenshot --instance-id i-xxxxx
```

### AWS CLI - Auto Scaling

```bash
# List Auto Scaling Groups
aws autoscaling describe-auto-scaling-groups

# Describe specific ASG
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names myapp-prod-asg

# List instances in ASG
aws autoscaling describe-auto-scaling-instances \
  --query 'AutoScalingInstances[?AutoScalingGroupName==`myapp-prod-asg`]'

# Set desired capacity
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name myapp-prod-asg \
  --desired-capacity 6

# Suspend scaling processes
aws autoscaling suspend-processes \
  --auto-scaling-group-name myapp-prod-asg \
  --scaling-processes Launch Terminate

# Resume scaling processes
aws autoscaling resume-processes \
  --auto-scaling-group-name myapp-prod-asg

# View scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name myapp-prod-asg \
  --max-records 20

# Attach instance to ASG
aws autoscaling attach-instances \
  --instance-ids i-xxxxx \
  --auto-scaling-group-name myapp-prod-asg

# Detach instance from ASG
aws autoscaling detach-instances \
  --instance-ids i-xxxxx \
  --auto-scaling-group-name myapp-prod-asg \
  --should-decrement-desired-capacity
```

### SSM Session Manager

```bash
# Start session
aws ssm start-session --target i-xxxxx

# Start session with port forwarding
aws ssm start-session \
  --target i-xxxxx \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["80"],"localPortNumber":["8080"]}'

# List active sessions
aws ssm describe-sessions --state Active

# Terminate session
aws ssm terminate-session --session-id session-xxxxx

# View session history
aws ssm describe-sessions --state History --max-results 10
```

### Terraform Commands

```bash
# Get all outputs
terraform output

# Get specific output
terraform output -raw bastion_eip

# Update bastion AMI
# Edit terraform.tfvars: bastion_ami_id = "ami-new"
terraform apply

# Destroy bastion only
terraform destroy -target=module.bastion[0]

# View state
terraform state list | grep bastion
terraform state show 'module.bastion[0].aws_instance.this[0]'
```

---

## 🎯 Configuration Templates

### Bastion Host

```hcl
# layers/compute/environments/prod/terraform.tfvars

enable_bastion = true

bastion_instance_type           = "t3.micro"
bastion_ami_id                  = "ami-xxxxx"
bastion_key_name                = "prod-bastion-key"
bastion_allowed_cidrs           = ["203.0.113.0/24"]
bastion_allocate_eip            = true
bastion_enable_cloudwatch_agent = true
bastion_root_volume_size        = 20
```

### Auto Scaling Group

```hcl
# Module usage
module "app_asg" {
  source = "../../modules/ec2"

  name          = "app"
  instance_type = "m5.large"
  ami_id        = var.app_ami_id

  create_autoscaling_group = true
  create_launch_template   = true

  subnet_ids             = var.private_subnet_ids
  vpc_security_group_ids = [var.app_sg_id]

  min_size         = 3
  max_size         = 15
  desired_capacity = 6

  target_group_arns = [var.target_group_arn]
  health_check_type = "ELB"

  target_tracking_policies = {
    cpu = {
      predefined_metric_type = "ASGAverageCPUUtilization"
      target_value           = 70
    }
  }
}
```

---

## 🔍 AMI Selection

### Find Latest Amazon Linux 2023

```bash
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-*" \
            "Name=architecture,Values=x86_64" \
  --query 'sort_by(Images, &CreationDate)[-1].[ImageId,Name,CreationDate]' \
  --output table
```

### Find Latest Ubuntu 22.04

```bash
aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  --query 'sort_by(Images, &CreationDate)[-1].[ImageId,Name,CreationDate]' \
  --output table
```

### In Terraform

```hcl
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

bastion_ami_id = data.aws_ami.amazon_linux_2023.id
```

---

## 🔐 SSH Key Management

### Create Key Pair

```bash
# Create key pair
aws ec2 create-key-pair \
  --key-name prod-bastion-key \
  --query 'KeyMaterial' \
  --output text > prod-bastion-key.pem

# Set permissions
chmod 400 prod-bastion-key.pem

# Import existing public key
aws ec2 import-key-pair \
  --key-name my-key \
  --public-key-material fileb://~/.ssh/id_rsa.pub
```

### List Key Pairs

```bash
aws ec2 describe-key-pairs \
  --query 'KeyPairs[*].[KeyName,KeyPairId]' \
  --output table
```

### Delete Key Pair

```bash
aws ec2 delete-key-pair --key-name old-key
```

---

## 📊 Instance Types

### General Purpose (T-Series)

| Type | vCPU | Memory | Price/Hour | Use Case |
|------|------|--------|------------|----------|
| t3.micro | 2 | 1 GB | $0.0104 | Bastion, dev |
| t3.small | 2 | 2 GB | $0.0208 | Small apps |
| t3.medium | 2 | 4 GB | $0.0416 | Web servers |
| t3.large | 2 | 8 GB | $0.0832 | Medium apps |

### General Purpose (M-Series)

| Type | vCPU | Memory | Price/Hour | Use Case |
|------|------|--------|------------|----------|
| m5.large | 2 | 8 GB | $0.096 | Balanced workloads |
| m5.xlarge | 4 | 16 GB | $0.192 | Applications |
| m5.2xlarge | 8 | 32 GB | $0.384 | Heavy workloads |

### Compute Optimized (C-Series)

| Type | vCPU | Memory | Price/Hour | Use Case |
|------|------|--------|------------|----------|
| c5.large | 2 | 4 GB | $0.085 | CPU-intensive |
| c5.xlarge | 4 | 8 GB | $0.17 | Batch processing |

---

## 🛠️ Troubleshooting

### Check Instance Status

```bash
# Detailed status
aws ec2 describe-instance-status \
  --instance-ids i-xxxxx \
  --include-all-instances

# System status check
aws ec2 describe-instance-status \
  --instance-ids i-xxxxx \
  --query 'InstanceStatuses[0].SystemStatus.Status'

# Instance status check
aws ec2 describe-instance-status \
  --instance-ids i-xxxxx \
  --query 'InstanceStatuses[0].InstanceStatus.Status'
```

### Debug User Data

```bash
# Connect to instance
aws ssm start-session --target i-xxxxx

# Check execution
sudo cat /var/log/user-data.log

# Check cloud-init
sudo cat /var/log/cloud-init-output.log
cloud-init status --long
```

### View Instance Console Output

```bash
aws ec2 get-console-output \
  --instance-id i-xxxxx \
  --latest \
  --output text
```

### ASG Not Scaling

```bash
# Check scaling policies
aws autoscaling describe-policies \
  --auto-scaling-group-name myapp-prod-asg

# Check CloudWatch alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix myapp-prod

# View metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=myapp-prod-asg \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

---

## 💡 Pro Tips

### 1. Use SSM Parameter Store for AMI IDs

```hcl
# Store AMI ID
resource "aws_ssm_parameter" "web_ami" {
  name  = "/myapp/prod/ami/web"
  type  = "String"
  value = "ami-xxxxx"
}

# Reference in config
data "aws_ssm_parameter" "web_ami" {
  name = "/myapp/prod/ami/web"
}

bastion_ami_id = data.aws_ssm_parameter.web_ami.value
```

### 2. Use Instance Metadata

```bash
# Inside instance
curl http://169.254.169.254/latest/meta-data/instance-id
curl http://169.254.169.254/latest/meta-data/local-ipv4
curl http://169.254.169.254/latest/meta-data/placement/availability-zone

# With IMDSv2 (more secure)
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id
```

### 3. Auto-Update AMIs

```hcl
# Use most_recent AMI
data "aws_ami" "app" {
  most_recent = true
  owners      = ["self"]  # Your account

  filter {
    name   = "name"
    values = ["myapp-*"]
  }
}

ami_id = data.aws_ami.app.id
```

### 4. Tag Instances Properly

```hcl
tags = {
  Name        = "myapp-prod-web"
  Environment = "production"
  Application = "web-server"
  Owner       = "platform-team"
  CostCenter  = "engineering"
  Backup      = "daily"  # For backup automation
}
```

---

## 🔄 Common Workflows

### Replace All Instances (Rolling Update)

```bash
# 1. Update AMI in terraform.tfvars
ami_id = "ami-new-version"

# 2. Enable instance refresh if not already
instance_refresh_enabled = true

# 3. Apply (triggers rolling update)
terraform apply

# 4. Monitor progress
aws autoscaling describe-instance-refreshes \
  --auto-scaling-group-name myapp-prod-asg
```

### Manual Scaling

```bash
# Scale up
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name myapp-prod-asg \
  --desired-capacity 10

# Scale down
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name myapp-prod-asg \
  --desired-capacity 4
```

### Drain Instance from ASG

```bash
# 1. Set instance to standby
aws autoscaling enter-standby \
  --instance-ids i-xxxxx \
  --auto-scaling-group-name myapp-prod-asg \
  --should-decrement-desired-capacity

# 2. Perform maintenance
# ...

# 3. Return to service
aws autoscaling exit-standby \
  --instance-ids i-xxxxx \
  --auto-scaling-group-name myapp-prod-asg
```

---

## 📈 Monitoring

### CloudWatch Metrics

```bash
# CPU Utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-xxxxx \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Network In
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name NetworkIn \
  --dimensions Name=InstanceId,Value=i-xxxxx \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

### Instance Health

```bash
# System status
aws ec2 describe-instance-status \
  --instance-ids i-xxxxx \
  --query 'InstanceStatuses[0].SystemStatus.Status'

# Instance status
aws ec2 describe-instance-status \
  --instance-ids i-xxxxx \
  --query 'InstanceStatuses[0].InstanceStatus.Status'
```

---

## 🎯 Module Configuration Examples

### Minimal Bastion

```hcl
module "bastion" {
  source = "../../modules/ec2"

  name          = "bastion"
  instance_type = "t3.micro"
  ami_id        = var.ami_id

  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.bastion_sg_id]
  associate_public_ip_address = true
  
  key_name = "bastion-key"

  tags = {
    Role = "bastion"
  }
}
```

### Production ASG

```hcl
module "app" {
  source = "../../modules/ec2"

  name          = "app"
  instance_type = "m5.large"
  ami_id        = var.app_ami_id

  create_autoscaling_group = true
  create_launch_template   = true

  subnet_ids = var.private_subnet_ids
  vpc_security_group_ids = [var.app_sg_id]

  min_size         = 3
  max_size         = 15
  desired_capacity = 6

  target_group_arns = [var.target_group_arn]
  health_check_type = "ELB"

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

---

## 🔑 User Data Examples

### Basic Setup

```bash
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "Hello World" > /var/www/html/index.html
```

### With CloudWatch Agent

```bash
#!/bin/bash
yum update -y
yum install -y amazon-cloudwatch-agent

# Configure and start agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c ssm:AmazonCloudWatch-Config
```

### With Docker

```bash
#!/bin/bash
yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Pull and run container
docker run -d -p 80:80 nginx:latest
```

---

## 📊 Auto Scaling Metrics

### Predefined Metric Types

```
ASGAverageCPUUtilization        - Average CPU across ASG
ASGAverageNetworkIn             - Average network in
ASGAverageNetworkOut            - Average network out
ALBRequestCountPerTarget        - Requests per instance (requires ALB)
```

### Custom Metrics

```bash
# Put custom metric
aws cloudwatch put-metric-data \
  --namespace MyApp \
  --metric-name ActiveConnections \
  --value 1500 \
  --dimensions AutoScalingGroupName=myapp-prod-asg
```

---

## 🚨 Emergency Procedures

### Stop All Scaling

```bash
# Suspend all processes
aws autoscaling suspend-processes \
  --auto-scaling-group-name myapp-prod-asg

# Resume when ready
aws autoscaling resume-processes \
  --auto-scaling-group-name myapp-prod-asg
```

### Force Instance Replacement

```bash
# Terminate specific instance
aws ec2 terminate-instances --instance-ids i-xxxxx

# ASG will automatically launch replacement
```

### Disable Auto Scaling Temporarily

```bash
# Set min/max/desired to same value
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name myapp-prod-asg \
  --min-size 4 \
  --max-size 4 \
  --desired-capacity 4
```

---

## 💰 Cost Optimization

### Use Appropriate Instance Types

```hcl
# Development
instance_type = "t3.micro"     # $7.50/month

# Production
instance_type = "t3.medium"    # $30/month
```

### Schedule Scaling

```hcl
# Scale down at night
autoscaling_schedules = {
  night = {
    desired_capacity = 2
    recurrence       = "0 22 * * *"
  }
}
```

### Use Spot for Non-Critical

For development/testing only.

---

## 📚 Additional Resources

- [EC2 Module README](modules/ec2/README.md)
- [EC2 Deployment Guide](EC2_DEPLOYMENT_GUIDE.md)
- [Compute Layer README](layers/compute/README.md)
- [AWS EC2 Pricing](https://aws.amazon.com/ec2/pricing/)

---

## 🆘 Quick Help

```bash
# Get instance ID from terraform
INSTANCE_ID=$(terraform output -raw bastion_instance_id)

# Connect via SSM
aws ssm start-session --target $INSTANCE_ID

# Check instance details
aws ec2 describe-instances --instance-ids $INSTANCE_ID

# View console logs
aws ec2 get-console-output --instance-id $INSTANCE_ID --output text

# Check security groups
aws ec2 describe-security-groups \
  --group-ids $(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
    --output text)
```

---

**EC2 Quick Reference v2.0**

