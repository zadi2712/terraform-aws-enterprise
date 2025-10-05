# Enterprise-Grade AWS Infrastructure with Terraform

## 🏗️ Architecture Overview

This repository contains a production-ready, enterprise-grade Terraform infrastructure following AWS Well-Architected Framework principles. The infrastructure is designed for multi-environment deployments with complete separation of concerns and follows industry best practices.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Directory Structure](#directory-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Layer-by-Layer Guide](#layer-by-layer-guide)
- [Environment Management](#environment-management)
- [Module Documentation](#module-documentation)
- [Best Practices](#best-practices)
- [Security Considerations](#security-considerations)
- [Contributing](#contributing)

## 🎯 Well-Architected Framework Alignment

This infrastructure implements all six pillars of the AWS Well-Architected Framework:

### 1. **Operational Excellence**
- Infrastructure as Code (IaC) with Terraform
- Automated deployments with state management
- Comprehensive tagging strategy
- Monitoring and observability built-in

### 2. **Security**
- Defense in depth with multiple security layers
- Encryption at rest and in transit
- IAM roles with least privilege principle
- WAF and Shield protection
- AWS Secrets Manager integration
- VPC security groups and NACLs

### 3. **Reliability**
- Multi-AZ deployments
- Auto-scaling configurations
- Backup and disaster recovery
- Health checks and self-healing

### 4. **Performance Efficiency**
- Right-sizing of resources
- CloudFront for content delivery
- ElastiCache for data caching
- Database read replicas

### 5. **Cost Optimization**
- Resource tagging for cost allocation
- Auto-scaling to match demand
- Reserved instances strategy
- S3 lifecycle policies

### 6. **Sustainability**
- Efficient resource utilization
- Auto-scaling to minimize waste
- Regional optimization
- Serverless options where applicable

## 📁 Directory Structure

```
terraform-aws-enterprise/
├── README.md                          # This file
├── .gitignore                         # Git ignore patterns
├── .pre-commit-config.yaml           # Pre-commit hooks
├── terraform.rc                       # Terraform CLI configuration
├── docs/                              # Documentation
│   ├── ARCHITECTURE.md               # Architecture decisions
│   ├── DEPLOYMENT.md                 # Deployment guide
│   ├── TROUBLESHOOTING.md           # Common issues and solutions
│   ├── SECURITY.md                   # Security guidelines
│   └── RUNBOOK.md                    # Operational runbook
├── layers/                            # Infrastructure layers
│   ├── networking/                   # VPC, subnets, routing
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   └── environments/
│   │       ├── dev/
│   │       │   ├── backend.conf
│   │       │   └── terraform.tfvars
│   │       ├── qa/
│   │       ├── uat/
│   │       └── prod/
│   ├── security/                     # IAM, KMS, Secrets
│   ├── dns/                          # Route53
│   ├── compute/                      # EC2, ECS, EKS, Lambda
│   ├── database/                     # RDS, DynamoDB
│   ├── storage/                      # S3, EFS, FSx
│   └── monitoring/                   # CloudWatch, SNS
└── modules/                           # Reusable modules
    ├── vpc/
    ├── ec2/
    ├── ecs/
    ├── eks/
    ├── lambda/
    ├── rds/
    ├── dynamodb/
    ├── s3/
    ├── efs/
    ├── alb/
    ├── cloudfront/
    ├── route53/
    ├── kms/
    ├── iam/
    ├── security-group/
    ├── cloudwatch/
    └── sns/
```

## 🚀 Quick Start

### Prerequisites

1. **Required Tools:**
   ```bash
   # Terraform >= 1.5.0
   terraform version

   # AWS CLI >= 2.0
   aws --version

   # Pre-commit (optional but recommended)
   pre-commit --version
   ```

2. **AWS Credentials:**
   ```bash
   # Configure AWS CLI
   aws configure

   # Or use environment variables
   export AWS_ACCESS_KEY_ID="your-access-key"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   export AWS_DEFAULT_REGION="us-east-1"
   ```

3. **S3 Backend Setup:**
   ```bash
   # Create S3 bucket for state files
   aws s3api create-bucket \
     --bucket terraform-state-${AWS_ACCOUNT_ID} \
     --region us-east-1

   # Enable versioning
   aws s3api put-bucket-versioning \
     --bucket terraform-state-${AWS_ACCOUNT_ID} \
     --versioning-configuration Status=Enabled

   # Enable encryption
   aws s3api put-bucket-encryption \
     --bucket terraform-state-${AWS_ACCOUNT_ID} \
     --server-side-encryption-configuration \
     '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

   # Create DynamoDB table for state locking
   aws dynamodb create-table \
     --table-name terraform-state-lock \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST
   ```

### Initial Deployment

The infrastructure follows a layered approach and must be deployed in order:

```bash
# 1. Deploy Networking Layer
cd layers/networking/environments/dev
terraform init -backend-config=backend.conf
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# 2. Deploy Security Layer
cd ../../security/environments/dev
terraform init -backend-config=backend.conf
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# 3. Deploy DNS Layer
cd ../../dns/environments/dev
terraform init -backend-config=backend.conf
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# 4. Deploy Database Layer
cd ../../database/environments/dev
terraform init -backend-config=backend.conf
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# 5. Deploy Storage Layer
cd ../../storage/environments/dev
terraform init -backend-config=backend.conf
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# 6. Deploy Compute Layer
cd ../../compute/environments/dev
terraform init -backend-config=backend.conf
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# 7. Deploy Monitoring Layer
cd ../../monitoring/environments/dev
terraform init -backend-config=backend.conf
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## 📚 Layer-by-Layer Guide

### 1. Networking Layer

**Purpose:** Foundation of the infrastructure - VPC, subnets, routing, NAT gateways

**Components:**
- Multi-AZ VPC with public and private subnets
- Internet Gateway and NAT Gateways
- Route tables and route associations
- VPC Flow Logs
- Network ACLs

**Dependencies:** None (deployed first)

### 2. Security Layer

**Purpose:** Identity, access management, and encryption

**Components:**
- IAM roles and policies
- KMS keys for encryption
- AWS Secrets Manager
- Security groups
- WAF rules

**Dependencies:** Networking

### 3. DNS Layer

**Purpose:** Domain management and routing

**Components:**
- Route53 hosted zones
- DNS records
- Health checks
- Traffic policies

**Dependencies:** Networking

### 4. Database Layer

**Purpose:** Data persistence and management

**Components:**
- RDS PostgreSQL/MySQL clusters
- DynamoDB tables
- ElastiCache Redis/Memcached
- DocumentDB
- Database subnet groups
- Parameter groups

**Dependencies:** Networking, Security

### 5. Storage Layer

**Purpose:** Object and file storage

**Components:**
- S3 buckets with lifecycle policies
- EFS file systems
- FSx for Windows/Lustre
- Backup vaults

**Dependencies:** Networking, Security

### 6. Compute Layer

**Purpose:** Application runtime and processing

**Components:**
- EC2 instances with Auto Scaling
- ECS clusters and services
- EKS clusters
- Lambda functions
- Application Load Balancers
- CloudFront distributions

**Dependencies:** Networking, Security, Database, Storage

### 7. Monitoring Layer

**Purpose:** Observability and alerting

**Components:**
- CloudWatch dashboards
- CloudWatch alarms
- SNS topics
- CloudWatch Logs
- AWS X-Ray
- EventBridge rules

**Dependencies:** All layers

## 🌍 Environment Management

### Environment Structure

Each environment (dev, qa, uat, prod) has its own:
- State file in S3
- Variable values
- Resource sizing
- Security policies

### Environment Promotion

```bash
# Promote configuration from dev to qa
cd layers/networking/environments/qa
# Review and update terraform.tfvars with QA-specific values
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### Environment Variables

Key differences per environment:

| Parameter | Dev | QA | UAT | Prod |
|-----------|-----|-----|-----|------|
| Instance Size | t3.small | t3.medium | t3.large | t3.xlarge |
| RDS Instance | db.t3.small | db.t3.medium | db.r5.large | db.r5.xlarge |
| Multi-AZ | false | true | true | true |
| Backup Retention | 1 day | 7 days | 14 days | 30 days |
| Auto Scaling Min | 1 | 2 | 2 | 3 |
| Auto Scaling Max | 2 | 4 | 6 | 10 |

## 🔧 Best Practices Implemented

### 1. State Management

- Remote state in S3 with encryption
- State locking with DynamoDB
- Separate state files per layer and environment
- State file versioning enabled

### 2. Code Organization
- DRY principles with modules
- Clear separation of concerns
- Consistent naming conventions
- Comprehensive variable validation

### 3. Security
- No hardcoded credentials
- Encryption at rest and in transit
- Least privilege IAM policies
- Security groups with minimal access
- AWS Secrets Manager for sensitive data

### 4. Tagging Strategy
```hcl
common_tags = {
  Environment     = "production"
  Project         = "enterprise-infrastructure"
  ManagedBy       = "terraform"
  CostCenter      = "engineering"
  Owner           = "platform-team"
  Compliance      = "pci-dss"
  DataClass       = "confidential"
  BackupPolicy    = "daily"
  PatchGroup      = "group-a"
}
```

### 5. Resource Naming
```
<service>-<environment>-<project>-<resource>-<identifier>
Example: ec2-prod-webapp-instance-01
```

## 🔒 Security Considerations
