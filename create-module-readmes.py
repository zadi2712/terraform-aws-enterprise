#!/usr/bin/env python3
"""
Final validation and creation of missing module READMEs
"""

import os
from pathlib import Path

BASE_DIR = "/Users/diego/terraform-aws-enterprise"

# Module READMEs
MODULE_READMES = {
    "ec2": '''# EC2 Instance Module

Production-ready EC2 instance module with Auto Scaling Group support.

## Features
- Auto Scaling Groups
- Launch Templates
- EBS volume management
- User data support
- Security group integration
- CloudWatch monitoring

## Usage

```hcl
module "web_servers" {
  source = "../../../modules/ec2"

  name          = "web-server"
  instance_type = "t3.medium"
  ami_id        = data.aws_ami.amazon_linux_2.id
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  min_size         = 2
  max_size         = 10
  desired_capacity = 4
  
  user_data = filebase64("${path.module}/user-data.sh")
  
  tags = {
    Environment = "production"
    Application = "web"
  }
}
```
''',
    
    "eks": '''# EKS Cluster Module

Amazon EKS (Elastic Kubernetes Service) cluster with managed node groups.

## Features
- EKS Control Plane
- Managed Node Groups
- IRSA (IAM Roles for Service Accounts)
- Cluster autoscaling
- Add-ons support (VPC CNI, CoreDNS, kube-proxy)

## Usage

```hcl
module "eks" {
  source = "../../../modules/eks"

  cluster_name    = "production-eks"
  cluster_version = "1.28"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  node_groups = {
    general = {
      desired_size   = 3
      min_size       = 2
      max_size       = 10
      instance_types = ["t3.large"]
    }
  }
  
  tags = {
    Environment = "production"
  }
}
```
''',
    
    "iam": '''# IAM Module

IAM roles, policies, and groups management.

## Features
- IAM Roles with trust policies
- IAM Policies (managed and inline)
- IAM Groups
- IAM Users (not recommended for applications)
- Policy attachments

## Usage

```hcl
module "app_role" {
  source = "../../../modules/iam"

  role_name = "application-role"
  
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
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]
  
  tags = {
    Environment = "production"
  }
}
```
''',
    
    "kms": '''# KMS Key Module

AWS Key Management Service encryption keys.

## Features
- KMS key creation
- Key rotation
- Key policies
- Aliases
- Multi-region keys support

## Usage

```hcl
module "encryption_key" {
  source = "../../../modules/kms"

  description             = "Encryption key for RDS"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  key_administrators = [
    "arn:aws:iam::123456789:role/admin-role"
  ]
  
  key_users = [
    "arn:aws:iam::123456789:role/application-role"
  ]
  
  tags = {
    Environment = "production"
  }
}
```
''',
    
    "efs": '''# EFS File System Module

Amazon Elastic File System for shared storage.

## Features
- EFS file system
- Mount targets across AZs
- Backup policy
- Lifecycle management
- Encryption at rest
- Access points

## Usage

```hcl
module "shared_storage" {
  source = "../../../modules/efs"

  name           = "shared-data"
  encrypted      = true
  kms_key_id     = module.kms.key_id
  
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
  security_group_ids = [module.efs_sg.security_group_id]
  
  lifecycle_policy = {
    transition_to_ia = "AFTER_30_DAYS"
  }
  
  tags = {
    Environment = "production"
  }
}
```
''',
    
    "sns": '''# SNS Topic Module

Amazon Simple Notification Service for alerts and notifications.

## Features
- SNS Topics
- Email subscriptions
- SMS subscriptions
- SQS subscriptions
- Lambda subscriptions
- Encryption support

## Usage

```hcl
module "alerts" {
  source = "../../../modules/sns"

  name         = "critical-alerts"
  display_name = "Critical Alerts"
  
  subscriptions = [
    {
      protocol = "email"
      endpoint = "ops-team@company.com"
    },
    {
      protocol = "sms"
      endpoint = "+1-555-0100"
    }
  ]
  
  kms_master_key_id = module.kms.key_id
  
  tags = {
    Environment = "production"
    AlertLevel  = "critical"
  }
}
```
''',
    
    "cloudwatch": '''# CloudWatch Module

Amazon CloudWatch dashboards, alarms, and log groups.

## Features
- CloudWatch Dashboards
- Metric Alarms
- Log Groups
- Metric Filters
- Composite Alarms

## Usage

```hcl
module "monitoring" {
  source = "../../../modules/cloudwatch"

  dashboard_name = "production-overview"
  
  log_groups = {
    application = {
      name              = "/aws/application/prod"
      retention_in_days = 30
    }
  }
  
  metric_alarms = {
    high_cpu = {
      alarm_name          = "high-cpu-utilization"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "CPUUtilization"
      namespace           = "AWS/EC2"
      period              = 300
      statistic           = "Average"
      threshold           = 80
      alarm_actions       = [module.sns.topic_arn]
    }
  }
  
  tags = {
    Environment = "production"
  }
}
```
''',
    
    "vpc-endpoints": '''# VPC Endpoints Module

Interface and Gateway VPC endpoints for AWS services.

## Features
- Interface Endpoints (PrivateLink)
- Gateway Endpoints (S3, DynamoDB)
- Security group management
- DNS resolution
- Multiple services support

## Usage

```hcl
module "vpc_endpoints" {
  source = "../../../modules/vpc-endpoints"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  endpoints = {
    ec2 = {
      service             = "ec2"
      private_dns_enabled = true
    }
    s3 = {
      service      = "s3"
      service_type = "Gateway"
    }
  }
  
  tags = {
    Environment = "production"
  }
}
```
'''
}

# Generate missing READMEs
print("🚀 Creating missing module READMEs...")
for module_name, content in MODULE_READMES.items():
    readme_path = f"{BASE_DIR}/modules/{module_name}/README.md"
    
    # Create module directory if it doesn't exist
    module_dir = f"{BASE_DIR}/modules/{module_name}"
    Path(module_dir).mkdir(parents=True, exist_ok=True)
    
    # Create README
    with open(readme_path, "w") as f:
        f.write(content)
    
    print(f"  ✅ Created README for {module_name}")

print("\n✅ All module READMEs created!")
