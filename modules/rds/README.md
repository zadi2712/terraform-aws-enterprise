# RDS Module

## Description

Enterprise-grade Amazon RDS module for relational database management supporting PostgreSQL, MySQL, MariaDB, Oracle, and SQL Server with encryption, backups, read replicas, and comprehensive monitoring.

## Features

- **Multiple Engines**: PostgreSQL, MySQL, MariaDB, Oracle, SQL Server
- **Encryption**: KMS encryption at rest and in transit
- **High Availability**: Multi-AZ deployments
- **Read Replicas**: Auto-scaling read capacity
- **Automatic Backups**: Point-in-time recovery
- **Storage Autoscaling**: Automatic storage expansion
- **Enhanced Monitoring**: Detailed performance metrics
- **Performance Insights**: Query performance analysis
- **IAM Authentication**: Database access via IAM
- **Blue/Green Deployments**: Zero-downtime updates
- **Secrets Manager**: Automatic password management
- **Parameter Groups**: Custom database tuning
- **Option Groups**: Database feature configuration
- **CloudWatch Logs**: Automatic log exports

## Resources Created

- `aws_db_instance` - Primary RDS instance
- `aws_db_instance` - Read replicas (optional)
- `aws_db_subnet_group` - Database subnet group
- `aws_db_parameter_group` - Custom parameters
- `aws_db_option_group` - Database options
- `aws_iam_role` - Enhanced monitoring role
- `aws_secretsmanager_secret` - Database credentials (optional)

## Usage

### Basic PostgreSQL Database

```hcl
module "postgres" {
  source = "../../modules/rds"

  identifier     = "myapp-db"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.medium"

  allocated_storage = 100
  storage_encrypted = true
  kms_key_id        = module.kms.key_arn

  database_name   = "myapp"
  master_username = "dbadmin"
  master_password = var.db_password  # From Secrets Manager or tfvars

  create_db_subnet_group = true
  subnet_ids             = module.vpc.database_subnet_ids
  vpc_security_group_ids = [module.db_sg.security_group_id]

  multi_az                = true
  backup_retention_period = 7

  tags = {
    Environment = "production"
  }
}
```

### Production Database with All Features

```hcl
module "postgres_prod" {
  source = "../../modules/rds"

  identifier     = "prod-postgres"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.r5.xlarge"

  # Storage
  allocated_storage     = 500
  max_allocated_storage = 2000  # Autoscale up to 2TB
  storage_type          = "gp3"
  iops                  = 12000
  storage_throughput    = 500
  storage_encrypted     = true
  kms_key_id            = module.kms_rds.key_arn

  # Database
  database_name   = "production"
  master_username = "dbadmin"
  
  # Use RDS-managed password in Secrets Manager
  manage_master_user_password   = true
  master_user_secret_kms_key_id = module.kms.key_arn

  # Network
  create_db_subnet_group = true
  subnet_ids             = module.vpc.database_subnet_ids
  vpc_security_group_ids = [module.rds_sg.id]
  multi_az               = true
  publicly_accessible    = false

  # Backups
  backup_retention_period = 35  # Maximum
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot   = true

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  monitoring_interval             = 60  # Enhanced monitoring every minute
  create_monitoring_role          = true
  performance_insights_enabled    = true
  performance_insights_kms_key_id = module.kms.key_arn
  performance_insights_retention_period = 731  # 2 years

  # Upgrades
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  apply_immediately           = false
  enable_blue_green_update    = true

  # Security
  deletion_protection                 = true
  iam_database_authentication_enabled = true
  skip_final_snapshot                 = false

  # Parameter group
  create_parameter_group  = true
  parameter_group_family  = "postgres15"
  
  parameters = [
    {
      name  = "shared_preload_libraries"
      value = "pg_stat_statements"
    },
    {
      name  = "log_statement"
      value = "all"
    }
  ]

  # Read replicas
  read_replicas = {
    replica1 = {
      instance_class               = "db.r5.large"
      multi_az                     = false
      availability_zone            = "us-east-1a"
      performance_insights_enabled = true
    }
    
    replica2 = {
      instance_class    = "db.r5.large"
      availability_zone = "us-east-1b"
    }
  }

  tags = {
    Environment = "production"
    Critical    = "true"
    Backup      = "required"
  }
}
```

### MySQL with Read Replicas

```hcl
module "mysql" {
  source = "../../modules/rds"

  identifier     = "myapp-mysql"
  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.m5.large"

  allocated_storage     = 200
  max_allocated_storage = 1000
  storage_encrypted     = true
  kms_key_id            = module.kms.key_arn

  database_name   = "myapp"
  master_username = "admin"
  master_password = var.db_password

  create_db_subnet_group = true
  subnet_ids             = module.vpc.database_subnet_ids
  vpc_security_group_ids = [module.mysql_sg.id]

  multi_az = true

  # MySQL specific logs
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  # Read replicas for scaling
  read_replicas = {
    read1 = {
      instance_class = "db.m5.large"
      multi_az       = false
    }
    
    read2 = {
      instance_class = "db.m5.large"
      multi_az       = false
    }
  }

  tags = {
    Application = "web-app"
  }
}
```

## Inputs

### Required

| Name | Description | Type |
|------|-------------|------|
| identifier | Database identifier | string |
| engine | Database engine | string |
| engine_version | Engine version | string |
| instance_class | Instance class | string |
| allocated_storage | Storage in GB | number |
| master_username | Master username | string |

### Storage

| Name | Description | Type | Default |
|------|-------------|------|---------|
| max_allocated_storage | Max storage for autoscaling | number | `null` |
| storage_type | Storage type | string | `"gp3"` |
| iops | IOPS for provisioned storage | number | `null` |
| storage_encrypted | Enable encryption | bool | `true` |
| kms_key_id | KMS key ARN | string | `null` |

### High Availability

| Name | Description | Type | Default |
|------|-------------|------|---------|
| multi_az | Enable Multi-AZ | bool | `false` |
| read_replicas | Map of read replicas | map(object) | `{}` |

### Backup & Recovery

| Name | Description | Type | Default |
|------|-------------|------|---------|
| backup_retention_period | Retention in days | number | `7` |
| backup_window | Backup window (UTC) | string | `"03:00-04:00"` |
| deletion_protection | Deletion protection | bool | `true` |
| skip_final_snapshot | Skip final snapshot | bool | `false` |

### Monitoring

| Name | Description | Type | Default |
|------|-------------|------|---------|
| monitoring_interval | Enhanced monitoring (seconds) | number | `0` |
| performance_insights_enabled | Enable Performance Insights | bool | `false` |
| enabled_cloudwatch_logs_exports | CloudWatch log types | list(string) | `[]` |

## Outputs

| Name | Description |
|------|-------------|
| db_instance_endpoint | Connection endpoint |
| db_instance_address | Database hostname |
| db_instance_port | Database port |
| read_replica_endpoints | Map of replica endpoints |
| master_password_secret_arn | Secrets Manager ARN |
| connection_info | Complete connection details |
| rds_info | Complete RDS information |

## Supported Engines

### PostgreSQL

```hcl
engine         = "postgres"
engine_version = "15.4"  # Latest: 15.x

# CloudWatch logs
enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

# Port
port = 5432  # Default
```

### MySQL

```hcl
engine         = "mysql"
engine_version = "8.0.35"  # Latest: 8.0.x

# CloudWatch logs
enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

# Port
port = 3306  # Default
```

### MariaDB

```hcl
engine         = "mariadb"
engine_version = "10.11.6"  # Latest: 10.11.x

# CloudWatch logs
enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
```

### Oracle

```hcl
engine         = "oracle-ee"  # or oracle-se2
engine_version = "19.0.0.0.ru-2023-10.rur-2023-10.r1"

license_model = "license-included"  # or bring-your-own-license
```

### SQL Server

```hcl
engine         = "sqlserver-ee"  # ee, se, ex, web
engine_version = "15.00.4335.1.v1"

license_model = "license-included"
```

## Instance Classes

### General Purpose (db.t/db.m)

| Class | vCPU | Memory | Use Case |
|-------|------|--------|----------|
| db.t3.micro | 2 | 1 GB | Dev/test |
| db.t3.small | 2 | 2 GB | Small apps |
| db.t3.medium | 2 | 4 GB | Medium apps |
| db.m5.large | 2 | 8 GB | Production |
| db.m5.xlarge | 4 | 16 GB | Large apps |

### Memory Optimized (db.r/db.x)

| Class | vCPU | Memory | Use Case |
|-------|------|--------|----------|
| db.r5.large | 2 | 16 GB | Memory-intensive |
| db.r5.xlarge | 4 | 32 GB | Large datasets |
| db.r5.2xlarge | 8 | 64 GB | Very large |

## Best Practices

### 1. Enable Multi-AZ (Production)

```hcl
multi_az = true
```

### 2. Use Encryption

```hcl
storage_encrypted = true
kms_key_id        = module.kms_rds.key_arn
```

### 3. Enable Backups

```hcl
backup_retention_period = 35  # Maximum for production
```

### 4. Use Secrets Manager

```hcl
manage_master_user_password   = true
master_user_secret_kms_key_id = module.kms.key_arn
```

### 5. Enable Performance Insights

```hcl
performance_insights_enabled    = true
performance_insights_kms_key_id = module.kms.key_arn
```

### 6. Use Storage Autoscaling

```hcl
allocated_storage     = 100
max_allocated_storage = 1000  # Auto-scale to 1TB
```

### 7. Deploy in Private Subnets

```hcl
publicly_accessible = false
subnet_ids          = module.vpc.database_subnet_ids
```

### 8. Enable Read Replicas

```hcl
read_replicas = {
  replica1 = {
    instance_class = "db.r5.large"
  }
}
```

## Security

### Encryption at Rest

```hcl
storage_encrypted = true
kms_key_id        = module.kms_rds.key_arn
```

### Encryption in Transit

```hcl
# Enable SSL/TLS in parameter group
parameters = [{
  name  = "rds.force_ssl"
  value = "1"
}]
```

### IAM Authentication

```hcl
iam_database_authentication_enabled = true

# Grant IAM user/role permission to connect
```

### Network Isolation

```hcl
publicly_accessible = false
vpc_security_group_ids = [module.rds_sg.id]
```

## Cost Optimization

### Storage Autoscaling

```hcl
allocated_storage     = 100   # Start small
max_allocated_storage = 1000  # Grow as needed
```

### Right-Size Instances

```hcl
# Development
instance_class = "db.t3.small"

# Production
instance_class = "db.r5.large"
```

### Use gp3 Storage

```hcl
storage_type = "gp3"  # 20% cheaper than gp2, better performance
```

### Optimize Backup Retention

```hcl
# Development
backup_retention_period = 7

# Production
backup_retention_period = 35
```

## Troubleshooting

### Cannot Connect

```bash
# Check security group allows your IP/CIDR
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Check DB is available
aws rds describe-db-instances --db-instance-identifier mydb

# Test connection
psql postgresql://username:password@endpoint:5432/dbname
```

### Slow Performance

```bash
# Enable Performance Insights
performance_insights_enabled = true

# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=mydb \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Storage Full

```hcl
# Enable storage autoscaling
max_allocated_storage = 1000  # Auto-expand
```

## References

- [RDS User Guide](https://docs.aws.amazon.com/rds/)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [RDS Pricing](https://aws.amazon.com/rds/pricing/)

## Related Modules

- [VPC Module](../vpc/README.md)
- [Security Group Module](../security-group/README.md)
- [KMS Module](../kms/README.md)
