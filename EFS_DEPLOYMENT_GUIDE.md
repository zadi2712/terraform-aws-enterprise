# EFS Deployment Guide

## Overview

Complete guide for deploying and managing Amazon Elastic File System (EFS) using the enterprise Terraform modules for shared, scalable NFS storage.

**Version:** 2.0  
**Last Updated:** October 20, 2025  
**Status:** ✅ Production Ready

---

## Table of Contents

1. [What is EFS](#what-is-efs)
2. [Use Cases](#use-cases)
3. [Prerequisites](#prerequisites)
4. [Deployment Steps](#deployment-steps)
5. [Configuration Guide](#configuration-guide)
6. [Mounting EFS](#mounting-efs)
7. [Performance Tuning](#performance-tuning)
8. [Cost Optimization](#cost-optimization)
9. [Security](#security)
10. [Troubleshooting](#troubleshooting)

---

## What is EFS

Amazon EFS provides scalable, elastic NFS file storage for use with AWS services and on-premises resources.

### Key Characteristics

- **Protocol**: NFS v4.1
- **Access**: Multiple EC2 instances simultaneously
- **Scalability**: Petabyte-scale, automatically grows/shrinks
- **Performance**: Up to 3 GiB/s throughput
- **Availability**: 99.99% SLA (Regional)
- **Durability**: Redundantly stored across multiple AZs

---

## Use Cases

### 1. Container Persistent Storage

**Best for:** ECS/EKS applications needing shared storage

```hcl
# Containers across multiple instances share same filesystem
module "container_storage" {
  source = "../../modules/efs"

  name = "ecs-persistent"
  
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.efs_sg.id]
  
  encrypted  = true
  kms_key_id = module.kms.key_arn

  access_points = {
    app_data = {
      posix_user = {
        gid = 1000
        uid = 1000
      }
      root_directory = {
        path = "/app-data"
        creation_info = {
          owner_gid   = 1000
          owner_uid   = 1000
          permissions = "755"
        }
      }
    }
  }
}
```

### 2. Web Application Shared Storage

**Best for:** WordPress, Drupal, shared uploads

```hcl
module "cms_uploads" {
  source = "../../modules/efs"

  name = "cms-uploads"
  
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.efs_sg.id]
  
  encrypted       = true
  throughput_mode = "elastic"

  access_points = {
    uploads = {
      posix_user = {
        gid = 33  # www-data
        uid = 33
      }
      root_directory = {
        path = "/uploads"
        creation_info = {
          owner_gid   = 33
          owner_uid   = 33
          permissions = "775"
        }
      }
    }
  }
}
```

### 3. Development Shared Storage

**Best for:** Team development environments

```hcl
module "dev_shared" {
  source = "../../modules/efs"

  name = "dev-shared"
  
  # One Zone for cost savings (47% cheaper)
  availability_zone_name = "us-east-1a"
  
  subnet_ids         = [module.vpc.private_subnets[0]]
  security_group_ids = [module.efs_sg.id]
  
  encrypted            = false  # Optional for dev
  enable_backup_policy = false  # Save costs
  transition_to_ia     = "AFTER_7_DAYS"
}
```

### 4. Machine Learning Data Lake

**Best for:** ML training data, big data analytics

```hcl
module "ml_datasets" {
  source = "../../modules/efs"

  name = "ml-data"
  
  # Max I/O for highly parallel workloads
  performance_mode                = "maxIO"
  throughput_mode                 = "provisioned"
  provisioned_throughput_in_mibps = 512

  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.efs_sg.id]
  
  encrypted  = true
  kms_key_id = module.kms.key_arn

  # Keep data in Standard storage
  transition_to_ia = null
}
```

---

## Prerequisites

### Required Infrastructure

1. **VPC** - Deployed networking layer
   ```bash
   cd layers/networking/environments/dev
   terraform apply
   ```

2. **Security Layer** - For KMS encryption (optional)
   ```bash
   cd layers/security/environments/dev
   terraform apply
   ```

3. **Private Subnets** - EFS mount targets need private subnets

### Tools Required

- Terraform >= 1.13.0
- AWS CLI v2
- amazon-efs-utils (for mounting)

---

## Deployment Steps

### Step 1: Enable EFS

Edit `layers/storage/environments/dev/terraform.tfvars`:

```hcl
# Enable EFS
enable_efs = true
```

### Step 2: Configure EFS Settings

```hcl
# Performance and throughput
efs_performance_mode = "generalPurpose"
efs_throughput_mode  = "elastic"  # Auto-scaling

# Storage class
efs_availability_zone_name = null  # Regional (multi-AZ)

# Encryption
efs_encrypted = true

# Lifecycle
efs_transition_to_ia = "AFTER_30_DAYS"  # Save 92% on storage

# Backup
efs_enable_backup_policy = true

# Access points (optional)
efs_access_points = {
  app = {
    posix_user = {
      gid = 1000
      uid = 1000
    }
    root_directory = {
      path = "/app"
      creation_info = {
        owner_gid   = 1000
        owner_uid   = 1000
        permissions = "755"
      }
    }
  }
}
```

### Step 3: Deploy

```bash
cd layers/storage/environments/dev
terraform init -backend-config=backend.conf -upgrade
terraform plan
terraform apply
```

### Step 4: Get EFS Details

```bash
# File system ID
terraform output efs_file_system_id

# DNS name for mounting
terraform output efs_dns_name

# Mount command
terraform output efs_mount_command
```

---

## Configuration Guide

### Performance Modes

#### General Purpose (Recommended)

```hcl
efs_performance_mode = "generalPurpose"
```

**Characteristics:**
- Latency: <10ms per operation
- IOPS: 35,000+ read, 7,000+ write
- Best for: 99% of workloads

**Use cases:**
- Web serving
- Content management
- Home directories
- General file storage

#### Max I/O

```hcl
efs_performance_mode = "maxIO"
```

**Characteristics:**
- Latency: Higher (tens of ms)
- IOPS: 500,000+
- Best for: Highly parallel workloads

**Use cases:**
- Big data analytics
- Media processing
- Genomics workflows

### Throughput Modes

#### Bursting (Cost-Effective)

```hcl
efs_throughput_mode = "bursting"
```

- Scales with file system size
- 50 MiB/s per TiB baseline
- Bursts to 100 MiB/s per TiB
- Best for variable workloads

#### Elastic (Recommended)

```hcl
efs_throughput_mode = "elastic"
```

- Automatically scales up/down
- Up to 3 GiB/s reads, 1 GiB/s writes
- Pay for what you use
- **Best for most workloads**

#### Provisioned

```hcl
efs_throughput_mode                 = "provisioned"
efs_provisioned_throughput_in_mibps = 256
```

- Fixed throughput independent of size
- Range: 1-1024 MiB/s
- Use when you know requirements

### Storage Classes

#### Regional (Default - Multi-AZ)

```hcl
efs_availability_zone_name = null
```

- **Availability:** 3+ AZs
- **Durability:** 99.999999999%
- **Use for:** Production, critical data

#### One Zone (47% Cheaper)

```hcl
efs_availability_zone_name = "us-east-1a"
```

- **Availability:** Single AZ
- **Durability:** 99.9%
- **Use for:** Dev/test, non-critical

### Lifecycle Management

#### Transition to Infrequent Access

```hcl
efs_transition_to_ia = "AFTER_30_DAYS"
```

**Options:**
- `AFTER_1_DAY`
- `AFTER_7_DAYS`
- `AFTER_14_DAYS`
- `AFTER_30_DAYS` ← **Recommended**
- `AFTER_60_DAYS`
- `AFTER_90_DAYS`

**Savings:** 92% ($0.30/GB → $0.025/GB)

#### Transition Back

```hcl
efs_transition_to_primary_storage_class = "AFTER_1_ACCESS"
```

Moves frequently accessed IA files back to Standard.

---

## Mounting EFS

### Prerequisites on EC2

```bash
# Amazon Linux 2023
sudo yum install -y amazon-efs-utils

# Ubuntu/Debian
sudo apt-get install -y amazon-efs-utils

# Or manual NFS client
sudo yum install -y nfs-utils  # Amazon Linux
sudo apt-get install -y nfs-common  # Ubuntu
```

### Mount with EFS Utils (Recommended)

```bash
# Get file system ID from terraform
FS_ID=$(terraform output -raw efs_file_system_id)

# Create mount point
sudo mkdir -p /mnt/efs

# Mount with encryption in transit
sudo mount -t efs -o tls $FS_ID:/ /mnt/efs

# Verify
df -h /mnt/efs
```

### Mount with Access Point

```bash
# Get access point ID
AP_ID=$(terraform output efs_access_point_ids | jq -r '.app')

# Mount
sudo mount -t efs -o tls,accesspoint=$AP_ID $FS_ID:/ /mnt/efs/app

# Verify ownership
ls -la /mnt/efs/app
# Should show uid:gid from access point config
```

### Auto-Mount on Boot

```bash
# Add to /etc/fstab
echo "$FS_ID:/ /mnt/efs efs _netdev,tls,iam 0 0" | sudo tee -a /etc/fstab

# Test mount
sudo mount -a

# Verify
df -h /mnt/efs
```

---

## ECS/EKS Integration

### ECS Task Definition

```json
{
  "family": "myapp",
  "containerDefinitions": [{
    "name": "app",
    "image": "myapp:latest",
    "mountPoints": [{
      "sourceVolume": "efs-storage",
      "containerPath": "/mnt/data"
    }]
  }],
  "volumes": [{
    "name": "efs-storage",
    "efsVolumeConfiguration": {
      "fileSystemId": "fs-12345678",
      "transitEncryption": "ENABLED",
      "authorizationConfig": {
        "accessPointId": "fsap-xxxxx",
        "iam": "ENABLED"
      }
    }
  }]
}
```

### Kubernetes Persistent Volume

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: efs-pv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: efs-sc
  csi:
    driver: efs.csi.aws.com
    volumeHandle: fs-12345678::fsap-xxxxx
```

### Kubernetes StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-12345678
  directoryPerms: "700"
  gidRangeStart: "1000"
  gidRangeEnd: "2000"
```

---

## Performance Tuning

### Optimize Mount Options

```bash
# Recommended mount options
sudo mount -t efs -o tls,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport $FS_ID:/ /mnt/efs
```

**Options explained:**
- `tls` - Encryption in transit
- `rsize/wsize=1048576` - 1 MB read/write size (optimal)
- `hard` - Retry on failure
- `timeo=600` - 60 second timeout
- `retrans=2` - 2 retransmissions
- `noresvport` - New port on reconnect

### For High Throughput Workloads

```hcl
# Use Elastic or Provisioned throughput
efs_throughput_mode = "elastic"

# Or provision specific throughput
efs_throughput_mode                 = "provisioned"
efs_provisioned_throughput_in_mibps = 512
```

### For High IOPS Workloads

```hcl
# Use Max I/O performance mode
efs_performance_mode = "maxIO"
```

---

## Cost Optimization

### 1. Use Lifecycle Management

```hcl
# Automatically move to IA storage (92% cheaper)
efs_transition_to_ia = "AFTER_30_DAYS"

# Move back on access
efs_transition_to_primary_storage_class = "AFTER_1_ACCESS"
```

**Savings Example:**
- 1 TB in Standard: $307/month
- 1 TB in IA: $26/month
- **Savings: $281/month**

### 2. Use One Zone for Dev/Test

```hcl
# 47% cost savings
efs_availability_zone_name = "us-east-1a"
```

**Pricing:**
- Regional Standard: $0.30/GB/month
- One Zone Standard: $0.16/GB/month
- **Savings: 47%**

### 3. Use Bursting Throughput

```hcl
# Most cost-effective
efs_throughput_mode = "bursting"

# Only use provisioned if needed
```

### 4. Clean Up Unused Files

```bash
# Find large files
find /mnt/efs -type f -size +100M -exec ls -lh {} \;

# Find old files
find /mnt/efs -type f -mtime +90 -exec ls -lh {} \;

# Delete if appropriate
```

---

## Security

### Encryption at Rest

```hcl
# Always encrypt in production
efs_encrypted  = true
efs_kms_key_id = data.terraform_remote_state.security.outputs.kms_key_arn
```

### Encryption in Transit

```bash
# Always use tls mount option
sudo mount -t efs -o tls $FS_ID:/ /mnt/efs
```

### Security Groups

```hcl
# Automatically created in storage layer
# Allows NFS (port 2049) from VPC only

ingress_rules = [{
  from_port   = 2049
  to_port     = 2049
  protocol    = "tcp"
  cidr_blocks = [module.vpc.vpc_cidr_block]
}]
```

### File System Policy

```hcl
# Enforce encryption in transit
efs_file_system_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [{
    Effect = "Deny"
    Principal = "*"
    Action = "*"
    Resource = aws_efs_file_system.this.arn
    Condition = {
      Bool = {
        "aws:SecureTransport" = "false"
      }
    }
  }]
})
```

### Access Points Security

```hcl
# Enforce specific user/group
access_points = {
  app = {
    posix_user = {
      gid = 1000
      uid = 1000  # Force this user
    }
  }
}
```

---

## Backup and DR

### Automatic Backups

```hcl
# Enable AWS Backup integration
efs_enable_backup_policy = true
```

Creates daily backups with 35-day retention (AWS Backup default).

### Cross-Region Replication

```hcl
# Enable replication for DR
efs_enable_replication             = true
efs_replication_destination_region = "us-west-2"
efs_replication_destination_kms_key_id = module.kms_west.key_arn
```

**Benefits:**
- Disaster recovery
- Multi-region applications
- Data sovereignty

---

## Monitoring

### CloudWatch Metrics

EFS automatically provides:
- `TotalIOBytes` - Total bytes transferred
- `ClientConnections` - Number of connected clients
- `DataReadIOBytes` - Bytes read
- `DataWriteIOBytes` - Bytes written
- `PercentIOLimit` - Percentage of I/O limit used

### View Metrics

```bash
# Total I/O
aws cloudwatch get-metric-statistics \
  --namespace AWS/EFS \
  --metric-name TotalIOBytes \
  --dimensions Name=FileSystemId,Value=fs-xxxxx \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

# Client connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/EFS \
  --metric-name ClientConnections \
  --dimensions Name=FileSystemId,Value=fs-xxxxx \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Create Alarms

```hcl
resource "aws_cloudwatch_metric_alarm" "efs_io_limit" {
  alarm_name          = "efs-io-limit"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "PercentIOLimit"
  namespace           = "AWS/EFS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EFS approaching I/O limit"
  
  dimensions = {
    FileSystemId = module.efs.file_system_id
  }
}
```

---

## Troubleshooting

### Issue: Cannot Mount EFS

**Check Prerequisites:**
```bash
# Check EFS utils installed
which mount.efs

# Check file system exists
aws efs describe-file-systems --file-system-id fs-xxxxx

# Check mount targets
aws efs describe-mount-targets --file-system-id fs-xxxxx

# Check security group allows NFS
aws ec2 describe-security-groups --group-ids sg-xxxxx
```

**Common Solutions:**
1. Install amazon-efs-utils
2. Verify security group allows port 2049 from instance
3. Ensure instance is in same VPC
4. Check mount target exists in instance's AZ

### Issue: Slow Performance

**Diagnose:**
```bash
# Check I/O limit
aws cloudwatch get-metric-statistics \
  --namespace AWS/EFS \
  --metric-name PercentIOLimit \
  --dimensions Name=FileSystemId,Value=fs-xxxxx \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Maximum
```

**Solutions:**
1. Switch to Elastic throughput mode
2. Switch to Max I/O performance mode (if highly parallel)
3. Optimize mount options
4. Check network connectivity

### Issue: Permission Denied

**Check Permissions:**
```bash
# On mount point
ls -la /mnt/efs

# Check POSIX user if using access point
# Must match access point configuration
```

**Solutions:**
1. Verify access point POSIX user configuration
2. Check directory permissions
3. Ensure correct uid/gid

### Issue: Stale File Handle

```bash
# Unmount and remount
sudo umount /mnt/efs
sudo mount -t efs -o tls $FS_ID:/ /mnt/efs
```

---

## Best Practices

### 1. Always Enable Encryption

```hcl
efs_encrypted  = true  # Production requirement
efs_kms_key_id = module.kms.key_arn
```

### 2. Use Access Points

```hcl
# Better than managing permissions directly
access_points = {
  app = {
    posix_user = { gid = 1000, uid = 1000 }
    root_directory = { path = "/app" }
  }
}
```

### 3. Enable Lifecycle Management

```hcl
# Save 92% on infrequently accessed data
efs_transition_to_ia = "AFTER_30_DAYS"
```

### 4. Enable Backups (Production)

```hcl
efs_enable_backup_policy = true
```

### 5. Use Elastic Throughput

```hcl
# Automatically scales with workload
efs_throughput_mode = "elastic"
```

### 6. Multi-AZ for Production

```hcl
# Regional storage
efs_availability_zone_name = null

# Not One Zone in production
```

### 7. Enable Replication (DR)

```hcl
# Production disaster recovery
efs_enable_replication             = true
efs_replication_destination_region = "us-west-2"
```

---

## Pricing Guide (us-east-1)

### Storage Pricing

| Storage Class | Price/GB/Month | Savings |
|--------------|----------------|---------|
| Standard | $0.30 | Baseline |
| Infrequent Access (IA) | $0.025 | 92% |
| One Zone | $0.16 | 47% |
| One Zone IA | $0.0133 | 96% |

### Throughput Pricing

| Mode | Price | Notes |
|------|-------|-------|
| Bursting | Free | Included |
| Elastic | $0.05/GB transferred | Pay for use |
| Provisioned | $6.00/MiB/s/month | Fixed cost |

### Example Costs

**100 GB, bursting, standard:**
- Storage: $30/month
- Throughput: $0
- **Total: $30/month**

**100 GB, elastic, with IA:**
- Storage (Standard): $21/month (70GB)
- Storage (IA): $0.75/month (30GB)
- Throughput: ~$5/month (varies)
- **Total: ~$27/month**

---

## References

- [EFS Module README](modules/efs/README.md)
- [AWS EFS User Guide](https://docs.aws.amazon.com/efs/)
- [EFS Performance](https://docs.aws.amazon.com/efs/latest/ug/performance.html)
- [EFS Pricing](https://aws.amazon.com/efs/pricing/)

---

**End of Deployment Guide**

