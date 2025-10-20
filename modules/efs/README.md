# EFS Module

## Description

Enterprise-grade Amazon Elastic File System (EFS) module for scalable, shared NFS file storage with encryption, lifecycle management, access points, and multi-region replication.

## Features

- **Shared File Storage**: NFS v4.1 protocol for multiple EC2 instances
- **Encryption**: KMS encryption at rest and in transit
- **Multi-AZ**: Automatic mount targets across availability zones
- **Access Points**: POSIX-compliant application-specific access
- **Lifecycle Management**: Automatic transition to Infrequent Access
- **Backup Policy**: Automatic backups via AWS Backup
- **Replication**: Cross-region disaster recovery
- **Performance Modes**: General Purpose or Max I/O
- **Throughput Modes**: Bursting, Provisioned, or Elastic
- **Security**: File system policies and security groups

## Resources Created

- `aws_efs_file_system` - EFS file system
- `aws_efs_mount_target` - Mount targets (one per subnet/AZ)
- `aws_efs_access_point` - Application-specific access points
- `aws_efs_backup_policy` - Automatic backup configuration
- `aws_efs_file_system_policy` - Resource-based access control
- `aws_efs_replication_configuration` - Cross-region replication

## Usage

### Basic EFS File System

```hcl
module "shared_storage" {
  source = "../../modules/efs"

  name = "shared-data"

  # Network
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.efs_sg.security_group_id]

  # Encryption
  encrypted  = true
  kms_key_id = module.kms.key_arn

  # Lifecycle
  transition_to_ia = "AFTER_30_DAYS"

  tags = {
    Environment = "production"
  }
}
```

### Production EFS with All Features

```hcl
module "app_efs" {
  source = "../../modules/efs"

  name             = "app-shared-storage"
  creation_token   = "prod-app-storage-2024"
  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"

  # Encryption
  encrypted  = true
  kms_key_id = module.kms.key_arn

  # Network (mount targets in all AZs)
  create_mount_targets = true
  subnet_ids = [
    module.vpc.private_subnets[0],  # us-east-1a
    module.vpc.private_subnets[1],  # us-east-1b
    module.vpc.private_subnets[2]   # us-east-1c
  ]
  security_group_ids = [module.efs_sg.security_group_id]

  # Lifecycle - save costs with IA storage
  transition_to_ia                    = "AFTER_30_DAYS"
  transition_to_primary_storage_class = "AFTER_1_ACCESS"

  # Backups
  enable_backup_policy = true

  # Access points for different applications
  access_points = {
    app1 = {
      posix_user = {
        gid = 1001
        uid = 1001
      }
      root_directory = {
        path = "/app1"
        creation_info = {
          owner_gid   = 1001
          owner_uid   = 1001
          permissions = "755"
        }
      }
    }
    
    app2 = {
      posix_user = {
        gid = 1002
        uid = 1002
      }
      root_directory = {
        path = "/app2"
        creation_info = {
          owner_gid   = 1002
          owner_uid   = 1002
          permissions = "750"
        }
      }
    }
  }

  # Replication for DR
  enable_replication                 = true
  replication_destination_region     = "us-west-2"
  replication_destination_kms_key_id = module.kms_west.key_arn

  tags = {
    Environment = "production"
    Application = "shared-storage"
    Backup      = "daily"
  }
}
```

### EFS for Container Storage

```hcl
module "container_storage" {
  source = "../../modules/efs"

  name = "ecs-persistent-storage"

  # Network - same VPC as ECS
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.efs_container_sg.security_group_id]

  # Encryption
  encrypted  = true
  kms_key_id = module.kms.key_arn

  # Performance for container workloads
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  # Lifecycle
  transition_to_ia = "AFTER_7_DAYS"

  # Access points for each service
  access_points = {
    service_a = {
      posix_user = {
        gid = 1000
        uid = 1000
      }
      root_directory = {
        path = "/service-a"
        creation_info = {
          owner_gid   = 1000
          owner_uid   = 1000
          permissions = "755"
        }
      }
    }
  }

  tags = {
    UsedBy = "ecs"
  }
}
```

### One Zone EFS (Cost Optimized)

```hcl
module "dev_storage" {
  source = "../../modules/efs"

  name = "dev-shared"

  # One Zone storage (47% cheaper than Regional)
  availability_zone_name = "us-east-1a"
  
  subnet_ids         = [module.vpc.private_subnets[0]]
  security_group_ids = [module.efs_sg.security_group_id]

  # Encryption
  encrypted  = true
  kms_key_id = module.kms.key_arn

  # Lifecycle
  transition_to_ia = "AFTER_7_DAYS"

  # Backup not needed for dev
  enable_backup_policy = false

  tags = {
    Environment = "development"
  }
}
```

## Inputs

### Required

| Name | Description | Type |
|------|-------------|------|
| name | Name of the EFS file system | string |

### File System Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| creation_token | Unique creation token | string | `null` |
| performance_mode | Performance mode | string | `"generalPurpose"` |
| throughput_mode | Throughput mode | string | `"bursting"` |
| provisioned_throughput_in_mibps | Provisioned throughput | number | `null` |
| availability_zone_name | One Zone AZ name | string | `null` |

### Encryption

| Name | Description | Type | Default |
|------|-------------|------|---------|
| encrypted | Enable encryption | bool | `true` |
| kms_key_id | KMS key ARN | string | `null` |

### Lifecycle

| Name | Description | Type | Default |
|------|-------------|------|---------|
| transition_to_ia | Transition to IA | string | `null` |
| transition_to_primary_storage_class | Transition back | string | `null` |

### Network

| Name | Description | Type | Default |
|------|-------------|------|---------|
| create_mount_targets | Create mount targets | bool | `true` |
| subnet_ids | Subnet IDs for mount targets | list(string) | `[]` |
| security_group_ids | Security group IDs | list(string) | `[]` |

### Access Points

| Name | Description | Type | Default |
|------|-------------|------|---------|
| access_points | Map of access points | map(object) | `{}` |

### Backup & Replication

| Name | Description | Type | Default |
|------|-------------|------|---------|
| enable_backup_policy | Enable AWS Backup | bool | `true` |
| enable_replication | Enable replication | bool | `false` |
| replication_destination_region | Destination region | string | `null` |

## Outputs

| Name | Description |
|------|-------------|
| file_system_id | EFS file system ID |
| file_system_arn | EFS file system ARN |
| file_system_dns_name | DNS name for mounting |
| mount_target_ids | List of mount target IDs |
| mount_target_dns_names | Mount target DNS names |
| access_point_ids | Map of access point IDs |
| mount_command_nfs | NFS mount command |
| mount_command_efs_utils | EFS utils mount command |
| efs_info | Complete EFS information |

## Performance Modes

### General Purpose (Default)

```hcl
performance_mode = "generalPurpose"
```

- **Best for:** Most workloads
- **Max Operations/Second:** 35,000+ (read), 7,000+ (write)
- **Latency:** Low, consistent
- **Use case:** Web serving, content management, development

### Max I/O

```hcl
performance_mode = "maxIO"
```

- **Best for:** Highly parallelized workloads
- **Max Operations/Second:** 500,000+
- **Latency:** Slightly higher
- **Use case:** Big data, media processing, genomics

## Throughput Modes

### Bursting (Default)

```hcl
throughput_mode = "bursting"
```

- **Throughput:** Scales with file system size
- **Burst:** Up to 100 MiB/s per TiB
- **Baseline:** 50 MiB/s per TiB
- **Best for:** Most applications

### Elastic (Recommended for Variable Workloads)

```hcl
throughput_mode = "elastic"
```

- **Throughput:** Automatically scales up/down
- **Max:** Up to 3 GiB/s reads, 1 GiB/s writes
- **Billing:** Pay for what you use
- **Best for:** Unpredictable workloads

### Provisioned

```hcl
throughput_mode                 = "provisioned"
provisioned_throughput_in_mibps = 100
```

- **Throughput:** Fixed, independent of size
- **Range:** 1-1024 MiB/s
- **Billing:** Pay for provisioned amount
- **Best for:** Known, consistent requirements

## Storage Classes

### Standard (Default)

- **Performance:** Low latency
- **Price:** $0.30/GB/month
- **Use:** Frequently accessed data

### Infrequent Access (IA)

```hcl
transition_to_ia = "AFTER_30_DAYS"
```

- **Performance:** Slightly higher latency
- **Price:** $0.025/GB/month (92% cheaper!)
- **Use:** Infrequently accessed data
- **Transition:** Automatic after specified days

### One Zone

```hcl
availability_zone_name = "us-east-1a"
```

- **Availability:** Single AZ
- **Price:** 47% cheaper than Standard
- **Use:** Dev/test, non-critical data

## Access Points

Access points provide application-specific entry points:

### Benefits

- **Isolation:** Separate root directories per application
- **Security:** Enforce user/group IDs
- **Simplification:** No need to manage permissions in-app

### Example

```hcl
access_points = {
  wordpress = {
    posix_user = {
      gid = 1000
      uid = 1000
    }
    root_directory = {
      path = "/wordpress"
      creation_info = {
        owner_gid   = 1000
        owner_uid   = 1000
        permissions = "755"
      }
    }
  }
  
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
```

## Mounting EFS

### Prerequisites

```bash
# Install EFS utils (Amazon Linux 2023)
sudo yum install -y amazon-efs-utils

# Or for Ubuntu
sudo apt-get install -y amazon-efs-utils
```

### Mount with EFS Utils (Recommended)

```bash
# Create mount point
sudo mkdir -p /mnt/efs

# Mount with encryption in transit
sudo mount -t efs -o tls fs-12345678:/ /mnt/efs

# Verify
df -h /mnt/efs
```

### Mount with Access Point

```bash
sudo mount -t efs -o tls,accesspoint=fsap-xxxxx fs-12345678:/ /mnt/efs/app1
```

### Auto-Mount on Boot (/etc/fstab)

```bash
# Add to /etc/fstab
fs-12345678:/ /mnt/efs efs _netdev,tls,iam 0 0

# Or with access point
fs-12345678:/ /mnt/efs efs _netdev,tls,iam,accesspoint=fsap-xxxxx 0 0
```

## Security

### Security Group Rules

```hcl
module "efs_sg" {
  source = "../security-group"

  name   = "efs-sg"
  vpc_id = module.vpc.vpc_id

  ingress_rules = [{
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
    description = "Allow NFS from VPC"
  }]

  tags = {
    Name = "efs-security-group"
  }
}
```

### File System Policy

```hcl
file_system_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Effect = "Allow"
      Principal = {
        AWS = "*"
      }
      Action = [
        "elasticfilesystem:ClientMount",
        "elasticfilesystem:ClientWrite"
      ]
      Resource = aws_efs_file_system.this.arn
      Condition = {
        Bool = {
          "elasticfilesystem:AccessedViaMountTarget" = "true"
        }
      }
    }
  ]
})
```

## Use Cases

### 1. Container Persistent Storage

```hcl
# EFS for ECS/EKS persistent volumes
module "container_storage" {
  source = "../../modules/efs"

  name = "ecs-storage"
  
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

```hcl
# WordPress/Drupal shared uploads
module "cms_storage" {
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

### 3. Machine Learning Data Lake

```hcl
# High-throughput for ML workloads
module "ml_storage" {
  source = "../../modules/efs"

  name = "ml-datasets"
  
  performance_mode                = "maxIO"
  throughput_mode                 = "provisioned"
  provisioned_throughput_in_mibps = 256

  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.efs_sg.id]
  
  encrypted  = true
  kms_key_id = module.kms.key_arn

  # Keep data in Standard storage
  transition_to_ia = null
}
```

## Cost Optimization

### Lifecycle Management

```hcl
# Transition to IA after 30 days (92% cheaper)
transition_to_ia = "AFTER_30_DAYS"

# Move back to Standard on first access
transition_to_primary_storage_class = "AFTER_1_ACCESS"
```

**Savings:** $0.30/GB → $0.025/GB for infrequently accessed data

### One Zone Storage

```hcl
# 47% cost savings
availability_zone_name = "us-east-1a"
```

**Use for:** Dev/test environments, non-critical data

### Right-Size Throughput

```hcl
# Bursting: Most cost-effective
throughput_mode = "bursting"

# Elastic: Pay for what you use
throughput_mode = "elastic"

# Provisioned: Only if you need guaranteed throughput
throughput_mode                 = "provisioned"
provisioned_throughput_in_mibps = 100
```

## Integration with ECS/EKS

### ECS Task Definition

```json
{
  "containerDefinitions": [{
    "name": "app",
    "mountPoints": [{
      "sourceVolume": "efs-storage",
      "containerPath": "/mnt/efs"
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
  accessModes:
    - ReadWriteMany
  csi:
    driver: efs.csi.aws.com
    volumeHandle: fs-12345678::fsap-xxxxx
```

## Best Practices

### 1. Enable Encryption

```hcl
encrypted  = true
kms_key_id = module.kms.key_arn
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
transition_to_ia = "AFTER_30_DAYS"  # Save 92% on storage costs
```

### 4. Enable Backups (Production)

```hcl
enable_backup_policy = true
```

### 5. Multi-AZ for Production

```hcl
# Regional (3 AZs)
subnet_ids = module.vpc.private_subnet_ids

# Not One Zone
availability_zone_name = null
```

### 6. Use Elastic Throughput

```hcl
throughput_mode = "elastic"  # Automatically scales
```

### 7. Enable Replication (DR)

```hcl
enable_replication             = true
replication_destination_region = "us-west-2"
```

## Performance Characteristics

| Mode | IOPS | Throughput | Latency | Use Case |
|------|------|------------|---------|----------|
| **General Purpose** | 35K read, 7K write | Scales with size | Low | Most workloads |
| **Max I/O** | 500K+ | Very high | Medium | Big data, parallel |
| **Bursting** | - | 100 MiB/s per TiB | - | Variable workloads |
| **Elastic** | - | Up to 3 GiB/s | - | Unpredictable |
| **Provisioned** | - | Fixed 1-1024 MiB/s | - | Consistent needs |

## Pricing (us-east-1)

| Storage Class | Price/GB/Month | Use Case |
|--------------|----------------|----------|
| **Standard** | $0.30 | Frequently accessed |
| **Infrequent Access** | $0.025 | Rarely accessed |
| **One Zone** | $0.16 | Dev/test |
| **One Zone IA** | $0.0133 | Dev/test IA |

**Data Transfer:** Free within same AZ

## Troubleshooting

### Mount Fails

```bash
# Check security group allows port 2049
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Check mount target status
aws efs describe-mount-targets --file-system-id fs-xxxxx

# Check EFS utils installed
which mount.efs

# Try with verbose logging
sudo mount -t efs -o tls,verbose fs-12345678:/ /mnt/efs
```

### Slow Performance

```bash
# Check current throughput mode
aws efs describe-file-systems --file-system-id fs-xxxxx

# Consider switching to elastic
throughput_mode = "elastic"

# Or increase provisioned throughput
provisioned_throughput_in_mibps = 256
```

### Access Denied

```bash
# Check access point configuration
aws efs describe-access-points --file-system-id fs-xxxxx

# Verify POSIX permissions
ls -la /mnt/efs

# Check file system policy
aws efs describe-file-system-policy --file-system-id fs-xxxxx
```

## References

- [EFS User Guide](https://docs.aws.amazon.com/efs/)
- [EFS Performance](https://docs.aws.amazon.com/efs/latest/ug/performance.html)
- [EFS Pricing](https://aws.amazon.com/efs/pricing/)
- [EFS CSI Driver](https://github.com/kubernetes-sigs/aws-efs-csi-driver)

## Related Modules

- [VPC Module](../vpc/README.md)
- [Security Group Module](../security-group/README.md)
- [KMS Module](../kms/README.md)
- [ECS Module](../ecs/README.md)
