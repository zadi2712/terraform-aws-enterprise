# RDS Deployment Guide

## Overview

Complete guide for deploying and managing Amazon RDS databases using the enterprise Terraform RDS module with encryption, backups, read replicas, and monitoring.

**Version:** 2.0  
**Last Updated:** October 20, 2025  
**Status:** ✅ Production Ready

---

## Table of Contents

1. [What is RDS](#what-is-rds)
2. [Supported Engines](#supported-engines)
3. [Prerequisites](#prerequisites)
4. [Deployment Steps](#deployment-steps)
5. [High Availability](#high-availability)
6. [Read Replicas](#read-replicas)
7. [Security](#security)
8. [Performance Tuning](#performance-tuning)
9. [Backup & Recovery](#backup--recovery)
10. [Monitoring](#monitoring)
11. [Cost Optimization](#cost-optimization)
12. [Troubleshooting](#troubleshooting)

---

## What is RDS

Amazon RDS is a managed relational database service that handles:
- Automated backups
- Software patching
- Automatic failure detection
- Multi-AZ deployments
- Read replicas
- Encryption at rest and in transit

### Benefits

✅ **No Server Management** - AWS handles infrastructure  
✅ **Automated Backups** - Point-in-time recovery  
✅ **High Availability** - Multi-AZ deployments  
✅ **Read Scaling** - Read replicas  
✅ **Security** - Encryption, IAM, network isolation  
✅ **Monitoring** - CloudWatch, Performance Insights  

---

## Supported Engines

### PostgreSQL (Recommended)

```hcl
rds_engine         = "postgres"
rds_engine_version = "15.4"  # Latest stable

rds_cloudwatch_logs_exports = ["postgresql", "upgrade"]
```

**Latest Versions:** 15.x, 14.x, 13.x  
**Port:** 5432

### MySQL

```hcl
rds_engine         = "mysql"
rds_engine_version = "8.0.35"

rds_cloudwatch_logs_exports = ["error", "general", "slowquery"]
```

**Latest Versions:** 8.0.x, 5.7.x (EOL soon)  
**Port:** 3306

### MariaDB

```hcl
rds_engine         = "mariadb"
rds_engine_version = "10.11.6"
```

### Oracle

```hcl
rds_engine = "oracle-ee"  # Enterprise Edition
# or "oracle-se2"  # Standard Edition
```

### SQL Server

```hcl
rds_engine = "sqlserver-ee"  # Enterprise
# Options: sqlserver-se, sqlserver-ex, sqlserver-web
```

---

## Prerequisites

### Required Infrastructure

1. **VPC with Database Subnets**
   ```bash
   cd layers/networking/environments/dev
   terraform apply
   ```

2. **KMS Key** (for encryption)
   ```bash
   cd layers/security/environments/dev
   # Set create_rds_key = true
   terraform apply
   ```

3. **Database Password**
   - Use RDS-managed (recommended)
   - Or store in Secrets Manager
   - Or environment variable

---

## Deployment Steps

### Step 1: Enable RDS

Edit `layers/database/environments/dev/terraform.tfvars`:

```hcl
create_rds = true
```

### Step 2: Configure Database

```hcl
# Engine
rds_engine         = "postgres"
rds_engine_version = "15.4"
rds_instance_type  = "db.t3.medium"

# Storage
rds_allocated_storage     = 100
rds_max_allocated_storage = 500  # Autoscale

# Database
database_name   = "myapp"
master_username = "dbadmin"

# Use RDS-managed password (recommended)
rds_manage_master_password = true
```

### Step 3: Configure High Availability

```hcl
# Multi-AZ for production
enable_multi_az = true

# Backups
backup_retention_days = 30
```

### Step 4: Deploy

```bash
cd layers/database/environments/dev
terraform init -backend-config=backend.conf -upgrade
terraform plan
terraform apply
```

### Step 5: Get Connection Info

```bash
# Endpoint
terraform output rds_endpoint

# Get password from Secrets Manager (if RDS-managed)
SECRET_ARN=$(terraform output -raw rds_master_password_secret_arn)
aws secretsmanager get-secret-value --secret-id $SECRET_ARN \
  --query 'SecretString' --output text | jq -r '.password'
```

### Step 6: Connect

```bash
# PostgreSQL
psql postgresql://dbadmin:PASSWORD@endpoint:5432/myapp

# MySQL
mysql -h endpoint -P 3306 -u dbadmin -p myapp
```

---

## High Availability

### Multi-AZ Deployment

```hcl
enable_multi_az = true
```

**How it works:**
- Primary in one AZ
- Standby replica in another AZ
- Automatic failover (1-2 minutes)
- Same endpoint (no code changes)

**When to use:**
- Production environments
- Business-critical applications
- SLA requirements

### Blue/Green Deployments

```hcl
rds_enable_blue_green_update = true
```

**Benefits:**
- Zero-downtime updates
- Easy rollback
- Test before switching

**Use for:**
- Major version upgrades
- Instance class changes
- Parameter group changes

---

## Read Replicas

### Create Read Replicas

```hcl
rds_read_replicas = {
  read1 = {
    instance_class    = "db.r5.large"
    multi_az          = false
    availability_zone = "us-east-1a"
    
    performance_insights_enabled = true
    monitoring_interval          = 60
  }
  
  read2 = {
    instance_class    = "db.r5.large"
    availability_zone = "us-east-1b"
  }
}
```

### Use Cases

- **Read Scaling** - Offload read traffic
- **Analytics** - Run reports without impacting primary
- **Cross-Region DR** - Promote replica in another region
- **Testing** - Test on replica data

### Connection

```bash
# Primary (read/write)
psql postgresql://user:pass@primary-endpoint:5432/db

# Replica (read-only)
psql postgresql://user:pass@replica-endpoint:5432/db
```

---

## Security

### Encryption at Rest

```hcl
storage_encrypted = true  # Always enabled in layer
# KMS key from security layer automatically applied
```

### Encryption in Transit

```hcl
# Enable SSL in parameter group
rds_parameters = [
  {
    name  = "rds.force_ssl"
    value = "1"
  }
]
```

### IAM Authentication

```hcl
rds_iam_authentication_enabled = true
```

**Usage:**
```bash
# Generate auth token
TOKEN=$(aws rds generate-db-auth-token \
  --hostname endpoint \
  --port 5432 \
  --username dbuser)

# Connect with IAM
psql "host=endpoint port=5432 dbname=mydb user=dbuser password=$TOKEN sslmode=require"
```

### Network Isolation

```hcl
rds_publicly_accessible = false  # Always false for production
# Deploy in private subnets
```

### Password Management

**Option 1: RDS-Managed (Recommended)**
```hcl
rds_manage_master_password = true
# RDS stores in Secrets Manager automatically
```

**Option 2: Secrets Manager**
```hcl
rds_store_password_in_secrets_manager = true
master_password = var.db_password
```

**Option 3: Environment Variable**
```bash
export TF_VAR_master_password="SecurePassword123!"
terraform apply
```

---

## Performance Tuning

### Instance Sizing

| Workload | Dev | QA | UAT | Prod |
|----------|-----|-----|-----|------|
| **Light** | db.t3.micro | db.t3.small | db.t3.medium | db.m5.large |
| **Medium** | db.t3.small | db.t3.medium | db.m5.large | db.r5.xlarge |
| **Heavy** | db.t3.medium | db.m5.large | db.r5.xlarge | db.r5.2xlarge |

### Storage Types

```hcl
# General Purpose (default)
rds_storage_type = "gp3"
rds_iops         = 3000  # gp3 baseline
rds_storage_throughput = 125  # gp3 baseline

# High Performance
rds_storage_type = "io2"
rds_iops         = 64000  # Up to 256k IOPS
```

### Performance Insights

```hcl
enable_performance_insights = true
rds_performance_insights_retention_period = 731  # 2 years
```

**View in Console:**
- RDS → Performance Insights
- Identify slow queries
- Optimize query performance

### Enhanced Monitoring

```hcl
rds_monitoring_interval = 60  # Every minute
```

**Provides:**
- OS-level metrics
- Process list
- Resource utilization

---

## Backup & Recovery

### Automated Backups

```hcl
backup_retention_days = 35  # Maximum
rds_backup_window     = "03:00-04:00"  # UTC
```

**Features:**
- Point-in-time recovery
- Daily automated snapshots
- Transaction log backups

### Manual Snapshots

```bash
# Create snapshot
aws rds create-db-snapshot \
  --db-instance-identifier mydb \
  --db-snapshot-identifier mydb-snapshot-$(date +%Y%m%d)

# List snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier mydb

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier mydb-restored \
  --db-snapshot-identifier mydb-snapshot-20241020
```

### Point-in-Time Recovery

```bash
# Restore to specific time
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier mydb \
  --target-db-instance-identifier mydb-restored \
  --restore-time 2024-10-20T12:00:00Z
```

---

## Monitoring

### CloudWatch Metrics

Key metrics:
- CPUUtilization
- DatabaseConnections
- FreeableMemory
- FreeStorageSpace
- ReadIOPS/WriteIOPS
- ReadLatency/WriteLatency

```bash
# Check CPU
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=mydb \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

### CloudWatch Logs

```hcl
rds_cloudwatch_logs_exports = ["postgresql", "upgrade"]
```

**View logs:**
```bash
aws logs tail /aws/rds/instance/mydb/postgresql --follow
```

---

## Cost Optimization

### Storage Autoscaling

```hcl
rds_allocated_storage     = 100   # Start here
rds_max_allocated_storage = 1000  # Grow as needed
```

### Use gp3 Storage

```hcl
rds_storage_type = "gp3"  # 20% cheaper than gp2
```

### Right-Size Instances

```hcl
# Start smaller
rds_instance_type = "db.t3.medium"

# Scale up based on CloudWatch metrics
```

### Reserved Instances

For production, purchase 1-year or 3-year RIs for 30-60% savings.

---

## Troubleshooting

### Cannot Connect

```bash
# Check security group
aws rds describe-db-instances \
  --db-instance-identifier mydb \
  --query 'DBInstances[0].VpcSecurityGroups'

# Test from EC2 in same VPC
telnet endpoint 5432

# Check subnet group
aws rds describe-db-subnet-groups \
  --db-subnet-group-name mydb-subnet-group
```

### High CPU

```bash
# Enable Performance Insights
enable_performance_insights = true

# Check slow queries
# Review in Performance Insights console
```

### Storage Full

```hcl
# Enable autoscaling
rds_max_allocated_storage = 1000
```

### Replication Lag

```bash
# Check replica lag
aws rds describe-db-instances \
  --db-instance-identifier mydb-replica \
  --query 'DBInstances[0].StatusInfos'

# Monitor ReplicaLag metric
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ReplicaLag \
  --dimensions Name=DBInstanceIdentifier,Value=mydb-replica \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

---

## Best Practices

1. ✅ **Always encrypt** - Use KMS encryption
2. ✅ **Multi-AZ in production** - Automatic failover
3. ✅ **Enable backups** - 35-day retention
4. ✅ **Use RDS-managed passwords** - Stored in Secrets Manager
5. ✅ **Enable Performance Insights** - Query optimization
6. ✅ **Deploy in private subnets** - Network isolation
7. ✅ **Use parameter groups** - Database tuning
8. ✅ **Enable deletion protection** - Prevent accidents
9. ✅ **Create read replicas** - Scale reads
10. ✅ **Monitor CloudWatch** - Proactive alerts

---

## References

- [RDS Module README](modules/rds/README.md)
- [AWS RDS User Guide](https://docs.aws.amazon.com/rds/)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [RDS Pricing](https://aws.amazon.com/rds/pricing/)

---

**End of Deployment Guide**

