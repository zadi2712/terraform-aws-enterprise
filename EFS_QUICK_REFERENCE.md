# EFS Quick Reference

## 🚀 Quick Start

### Deploy EFS

```bash
cd layers/storage/environments/dev

# Edit terraform.tfvars
enable_efs = true

# Deploy
terraform init -backend-config=backend.conf -upgrade
terraform apply

# Get file system ID
terraform output efs_file_system_id
```

### Mount EFS

```bash
# Install EFS utils
sudo yum install -y amazon-efs-utils

# Get FS ID
FS_ID=$(terraform output -raw efs_file_system_id)

# Mount
sudo mkdir -p /mnt/efs
sudo mount -t efs -o tls $FS_ID:/ /mnt/efs

# Verify
df -h /mnt/efs
```

---

## 📋 Common Commands

### AWS CLI - File Systems

```bash
# List file systems
aws efs describe-file-systems

# Describe specific file system
aws efs describe-file-systems --file-system-id fs-xxxxx

# Get file system size
aws efs describe-file-systems \
  --file-system-id fs-xxxxx \
  --query 'FileSystems[0].SizeInBytes' \
  --output json

# Update throughput mode
aws efs update-file-system \
  --file-system-id fs-xxxxx \
  --throughput-mode elastic

# Delete file system
aws efs delete-file-system --file-system-id fs-xxxxx
```

### AWS CLI - Mount Targets

```bash
# List mount targets
aws efs describe-mount-targets --file-system-id fs-xxxxx

# Describe mount target
aws efs describe-mount-targets --mount-target-id fsmt-xxxxx

# Create mount target
aws efs create-mount-target \
  --file-system-id fs-xxxxx \
  --subnet-id subnet-xxxxx \
  --security-groups sg-xxxxx

# Delete mount target
aws efs delete-mount-target --mount-target-id fsmt-xxxxx
```

### AWS CLI - Access Points

```bash
# List access points
aws efs describe-access-points --file-system-id fs-xxxxx

# Describe specific access point
aws efs describe-access-points --access-point-id fsap-xxxxx

# Delete access point
aws efs delete-access-point --access-point-id fsap-xxxxx
```

### Mount Commands

```bash
# Basic mount with EFS utils
sudo mount -t efs -o tls fs-12345678:/ /mnt/efs

# Mount with access point
sudo mount -t efs -o tls,accesspoint=fsap-xxxxx fs-12345678:/ /mnt/efs/app

# Mount with all options
sudo mount -t efs -o tls,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 fs-12345678:/ /mnt/efs

# Traditional NFS mount
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576 fs-12345678.efs.us-east-1.amazonaws.com:/ /mnt/efs

# Unmount
sudo umount /mnt/efs
```

### Terraform Commands

```bash
# Get outputs
terraform output efs_file_system_id
terraform output efs_dns_name
terraform output efs_mount_command
terraform output efs_access_point_ids

# Get complete info
terraform output efs_info | jq '.'

# Enable EFS
# Edit terraform.tfvars: enable_efs = true
terraform apply

# Disable EFS
# Edit terraform.tfvars: enable_efs = false
terraform apply
```

---

## 🎯 Configuration Templates

### Development (Cost-Optimized)

```hcl
# layers/storage/environments/dev/terraform.tfvars

enable_efs = true

efs_performance_mode       = "generalPurpose"
efs_throughput_mode        = "bursting"
efs_availability_zone_name = "us-east-1a"  # One Zone (47% cheaper)
efs_encrypted              = false
efs_transition_to_ia       = "AFTER_7_DAYS"
efs_enable_backup_policy   = false
```

### Production (High Availability)

```hcl
# layers/storage/environments/prod/terraform.tfvars

enable_efs = true

efs_performance_mode       = "generalPurpose"
efs_throughput_mode        = "elastic"  # Auto-scaling
efs_availability_zone_name = null       # Regional (multi-AZ)
efs_encrypted              = true
efs_transition_to_ia       = "AFTER_30_DAYS"
efs_enable_backup_policy   = true
efs_enable_replication     = true
efs_replication_destination_region = "us-west-2"

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

---

## 📊 Performance Modes

| Mode | IOPS | Latency | Use Case |
|------|------|---------|----------|
| **General Purpose** | 35K read, 7K write | <10ms | Most workloads |
| **Max I/O** | 500K+ | Tens of ms | Big data, parallel |

### Switch Performance Mode

```bash
# Cannot change after creation!
# Must create new file system and migrate data
```

---

## 🔄 Throughput Modes

| Mode | Throughput | Cost | Switching |
|------|------------|------|-----------|
| **Bursting** | Scales with size | Included | Can switch |
| **Elastic** | Up to 3 GiB/s | Pay per GB | Can switch |
| **Provisioned** | 1-1024 MiB/s | Fixed | Can switch |

### Switch Throughput Mode

```bash
# Can change anytime
aws efs update-file-system \
  --file-system-id fs-xxxxx \
  --throughput-mode elastic

# Or in Terraform
efs_throughput_mode = "elastic"
terraform apply
```

---

## 💾 Storage Classes

### Lifecycle Transitions

```
Standard (frequent access)
    │
    │ After N days of no access
    ▼
Infrequent Access (IA)
    │
    │ On first access
    ▼
Standard (back to frequent)
```

### Configuration

```hcl
efs_transition_to_ia                    = "AFTER_30_DAYS"
efs_transition_to_primary_storage_class = "AFTER_1_ACCESS"
```

---

## 🔑 Access Points

### Create Access Point

```hcl
efs_access_points = {
  myapp = {
    posix_user = {
      gid = 1000
      uid = 1000
    }
    root_directory = {
      path = "/myapp"
      creation_info = {
        owner_gid   = 1000
        owner_uid   = 1000
        permissions = "755"
      }
    }
  }
}
```

### Mount Access Point

```bash
AP_ID=$(terraform output efs_access_point_ids | jq -r '.myapp')
FS_ID=$(terraform output -raw efs_file_system_id)

sudo mount -t efs -o tls,accesspoint=$AP_ID $FS_ID:/ /mnt/efs/myapp
```

---

## 🐳 Container Integration

### ECS Task Definition

```json
{
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

### ECS Task IAM Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite"
    ],
    "Resource": "arn:aws:elasticfilesystem:us-east-1:123456789012:file-system/fs-xxxxx",
    "Condition": {
      "StringEquals": {
        "elasticfilesystem:AccessPointArn": "arn:aws:elasticfilesystem:us-east-1:123456789012:access-point/fsap-xxxxx"
      }
    }
  }]
}
```

### Kubernetes PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi
```

---

## 🛠️ Troubleshooting

### Check Mount Status

```bash
# List mounted filesystems
mount | grep efs

# Check mount point
df -h /mnt/efs

# Show mount options
mount | grep $(terraform output -raw efs_file_system_id)
```

### Debug Mount Issues

```bash
# Verbose mount
sudo mount -t efs -o tls,verbose fs-xxxxx:/ /mnt/efs

# Check logs
sudo tail -f /var/log/messages
sudo journalctl -u nfs-client.target -f

# Test NFS connectivity
telnet fs-xxxxx.efs.us-east-1.amazonaws.com 2049
```

### Check File System Status

```bash
# Describe file system
aws efs describe-file-systems \
  --file-system-id fs-xxxxx \
  --query 'FileSystems[0].[LifeCycleState,NumberOfMountTargets]'

# Check mount target state
aws efs describe-mount-targets \
  --file-system-id fs-xxxxx \
  --query 'MountTargets[*].[MountTargetId,LifeCycleState,IpAddress]'
```

### Performance Issues

```bash
# Check I/O metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EFS \
  --metric-name PercentIOLimit \
  --dimensions Name=FileSystemId,Value=fs-xxxxx \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# Switch to elastic if hitting limits
terraform apply -var="efs_throughput_mode=elastic"
```

---

## 💰 Cost Optimization

### Quick Wins

```hcl
# 1. Use lifecycle management (92% savings on IA)
efs_transition_to_ia = "AFTER_30_DAYS"

# 2. Use One Zone for dev (47% savings)
efs_availability_zone_name = "us-east-1a"

# 3. Use bursting for variable workloads
efs_throughput_mode = "bursting"

# 4. Disable backups in dev
efs_enable_backup_policy = false
```

### Cost Calculation

```bash
# Get current size
aws efs describe-file-systems \
  --file-system-id fs-xxxxx \
  --query 'FileSystems[0].SizeInBytes.Value' \
  --output text

# Calculate monthly cost
# Standard: size_gb * $0.30
# IA: size_gb * $0.025
```

---

## 🔐 Security Checklist

- [ ] Encryption at rest enabled
- [ ] KMS key configured
- [ ] Encryption in transit (tls mount option)
- [ ] Security group allows only VPC
- [ ] Access points configured (if needed)
- [ ] File system policy set (if needed)
- [ ] IAM permissions granted (for ECS/Lambda)
- [ ] No public access

---

## 📈 Monitoring

### Key Metrics

```bash
# Total I/O
aws cloudwatch get-metric-statistics \
  --namespace AWS/EFS \
  --metric-name TotalIOBytes \
  --dimensions Name=FileSystemId,Value=fs-xxxxx \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
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

---

## 🆘 Emergency Procedures

### Unmount All

```bash
# Find all EFS mounts
mount | grep efs

# Unmount all
sudo umount -a -t efs

# Or specific mount
sudo umount /mnt/efs
```

### Force Unmount

```bash
# If busy
sudo umount -f /mnt/efs

# If still stuck
sudo umount -l /mnt/efs  # Lazy unmount
```

### Recover from Stale Handle

```bash
# Unmount
sudo umount /mnt/efs

# Remount
sudo mount -t efs -o tls fs-xxxxx:/ /mnt/efs
```

---

## 📚 Additional Resources

- [EFS Module README](modules/efs/README.md)
- [EFS Deployment Guide](EFS_DEPLOYMENT_GUIDE.md)
- [Storage Layer README](layers/storage/README.md)
- [AWS EFS Documentation](https://docs.aws.amazon.com/efs/)

---

## 💡 Pro Tips

### 1. Use EFS Utils

```bash
# Better than manual NFS
sudo mount -t efs -o tls fs-xxxxx:/ /mnt/efs

# Benefits:
# - Automatic encryption in transit
# - Better error handling
# - IAM authentication support
# - Stunnel integration
```

### 2. Test Before Production

```bash
# Create test file
sudo touch /mnt/efs/test.txt

# Check from another instance
ssh another-instance
ls -la /mnt/efs/test.txt  # Should see same file
```

### 3. Monitor I/O

```bash
# Check if hitting limits
aws cloudwatch get-metric-statistics \
  --namespace AWS/EFS \
  --metric-name PercentIOLimit \
  --dimensions Name=FileSystemId,Value=fs-xxxxx \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Maximum

# If > 80%, switch to elastic
```

### 4. Use Access Points

```bash
# Easier permission management
# No need to manage POSIX permissions manually
```

---

**EFS Quick Reference v2.0**

