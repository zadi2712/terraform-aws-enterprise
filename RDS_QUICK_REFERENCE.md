# RDS Quick Reference

## 🚀 Quick Start

### Deploy RDS

```bash
cd layers/database/environments/dev

# Edit terraform.tfvars
create_rds = true
master_password = "SecurePassword123!"
# Or use: rds_manage_master_password = true

# Deploy
terraform init -backend-config=backend.conf -upgrade
terraform apply

# Get endpoint
terraform output rds_endpoint
```

### Connect to Database

```bash
# PostgreSQL
ENDPOINT=$(terraform output -raw rds_endpoint)
psql postgresql://dbadmin:PASSWORD@$ENDPOINT/myapp

# MySQL
mysql -h $(terraform output -raw rds_address) -P 5432 -u dbadmin -p myapp
```

---

## 📋 Common Commands

### AWS CLI - Instances

```bash
# List instances
aws rds describe-db-instances

# Describe specific instance
aws rds describe-db-instances --db-instance-identifier mydb

# Modify instance
aws rds modify-db-instance \
  --db-instance-identifier mydb \
  --allocated-storage 200 \
  --apply-immediately

# Reboot instance
aws rds reboot-db-instance --db-instance-identifier mydb

# Delete instance
aws rds delete-db-instance \
  --db-instance-identifier mydb \
  --final-db-snapshot-identifier mydb-final-snapshot
```

### AWS CLI - Snapshots

```bash
# Create snapshot
aws rds create-db-snapshot \
  --db-instance-identifier mydb \
  --db-snapshot-identifier mydb-$(date +%Y%m%d)

# List snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier mydb

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier mydb-restored \
  --db-snapshot-identifier mydb-20241020

# Delete snapshot
aws rds delete-db-snapshot --db-snapshot-identifier mydb-old
```

### AWS CLI - Monitoring

```bash
# Check instance status
aws rds describe-db-instances \
  --db-instance-identifier mydb \
  --query 'DBInstances[0].DBInstanceStatus'

# Get CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=mydb \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# View logs
aws rds download-db-log-file-portion \
  --db-instance-identifier mydb \
  --log-file-name error/postgresql.log.2024-10-20-12
```

---

## 🎯 Configuration Templates

### Development

```hcl
create_rds = true

rds_engine         = "postgres"
rds_engine_version = "15.4"
rds_instance_type  = "db.t3.micro"

rds_allocated_storage     = 20
rds_max_allocated_storage = 100

enable_multi_az = false
backup_retention_days = 3

rds_deletion_protection = false
rds_skip_final_snapshot = true
```

### Production

```hcl
create_rds = true

rds_engine         = "postgres"
rds_engine_version = "15.4"
rds_instance_type  = "db.r5.xlarge"

rds_allocated_storage     = 500
rds_max_allocated_storage = 2000
rds_storage_type          = "gp3"
rds_iops                  = 12000

enable_multi_az = true
backup_retention_days = 35

rds_manage_master_password = true
enable_performance_insights = true
rds_monitoring_interval = 60

rds_deletion_protection = true
rds_skip_final_snapshot = false

rds_read_replicas = {
  read1 = { instance_class = "db.r5.large" }
  read2 = { instance_class = "db.r5.large" }
}
```

---

## 💰 Pricing Examples

**db.t3.micro (Dev):**
- Instance: ~$12/month
- Storage (20GB gp3): ~$2.30/month
- **Total:** ~$15/month

**db.r5.xlarge (Prod):**
- Instance: ~$360/month
- Storage (500GB gp3): ~$58/month
- Backups: ~$5/month
- **Total:** ~$425/month (primary + 2 replicas = ~$1,000/month)

---

## 🔍 Monitoring

### Key Metrics

```bash
# CPU
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=mydb \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Average,Maximum

# Connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=mydb \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Storage
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name FreeStorageSpace \
  --dimensions Name=DBInstanceIdentifier,Value=mydb \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Minimum
```

---

## 🆘 Troubleshooting

### Connection Issues

```bash
# Test from bastion
telnet endpoint 5432

# Check security group
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Verify subnet group
aws rds describe-db-subnet-groups
```

### Performance Issues

```bash
# Enable Performance Insights
enable_performance_insights = true

# Check slow queries in PI console
# Tune parameters or add indexes
```

### Storage Issues

```hcl
# Enable autoscaling
rds_max_allocated_storage = 1000
```

---

## 📚 Additional Resources

- [RDS Module README](modules/rds/README.md)
- [RDS Deployment Guide](RDS_DEPLOYMENT_GUIDE.md)
- [Database Layer README](layers/database/README.md)
- [AWS RDS Documentation](https://docs.aws.amazon.com/rds/)

---

**RDS Quick Reference v2.0**

