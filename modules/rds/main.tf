################################################################################
# RDS Module - Enterprise Database Management
# Version: 2.0
# Description: RDS instances with encryption, backups, replicas, and monitoring
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  common_tags = merge(
    var.tags,
    {
      Module    = "rds"
      ManagedBy = "terraform"
    }
  )

  # Default ports for different engines
  default_port = {
    postgres  = 5432
    mysql     = 3306
    mariadb   = 3306
    oracle-ee = 1521
    oracle-se2 = 1521
    sqlserver-ee = 1433
    sqlserver-se = 1433
    sqlserver-ex = 1433
    sqlserver-web = 1433
  }
}

################################################################################
# DB Subnet Group
################################################################################

resource "aws_db_subnet_group" "this" {
  count = var.create_db_subnet_group ? 1 : 0

  name        = var.db_subnet_group_name != null ? var.db_subnet_group_name : "${var.identifier}-subnet-group"
  description = "Subnet group for ${var.identifier}"
  subnet_ids  = var.subnet_ids

  tags = merge(
    local.common_tags,
    {
      Name = var.db_subnet_group_name != null ? var.db_subnet_group_name : "${var.identifier}-subnet-group"
    }
  )
}

################################################################################
# DB Parameter Group
################################################################################

resource "aws_db_parameter_group" "this" {
  count = var.create_parameter_group ? 1 : 0

  name        = "${var.identifier}-params"
  family      = var.parameter_group_family
  description = "Custom parameter group for ${var.identifier}"

  dynamic "parameter" {
    for_each = var.parameters

    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = lookup(parameter.value, "apply_method", "immediate")
    }
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# DB Option Group
################################################################################

resource "aws_db_option_group" "this" {
  count = var.create_option_group ? 1 : 0

  name                     = "${var.identifier}-options"
  option_group_description = "Option group for ${var.identifier}"
  engine_name              = var.engine
  major_engine_version     = var.major_engine_version

  dynamic "option" {
    for_each = var.options

    content {
      option_name = option.value.option_name

      dynamic "option_settings" {
        for_each = lookup(option.value, "option_settings", [])

        content {
          name  = option_settings.value.name
          value = option_settings.value.value
        }
      }
    }
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Enhanced Monitoring IAM Role
################################################################################

resource "aws_iam_role" "enhanced_monitoring" {
  count = var.create_monitoring_role && var.monitoring_interval > 0 ? 1 : 0

  name = "${var.identifier}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  count = var.create_monitoring_role && var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

################################################################################
# RDS Instance
################################################################################

resource "aws_db_instance" "this" {
  identifier = var.identifier

  # Engine configuration
  engine               = var.engine
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  license_model        = var.license_model
  ca_cert_identifier   = var.ca_cert_identifier

  # Storage configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.storage_encrypted && var.kms_key_id != null ? var.kms_key_id : null
  iops                  = var.iops
  storage_throughput    = var.storage_throughput

  # Database configuration
  db_name  = var.database_name
  username = var.master_username
  password = var.manage_master_user_password ? null : var.master_password
  port     = var.port != null ? var.port : lookup(local.default_port, var.engine, 5432)

  # Managed master password
  manage_master_user_password   = var.manage_master_user_password
  master_user_secret_kms_key_id = var.manage_master_user_password && var.master_user_secret_kms_key_id != null ? var.master_user_secret_kms_key_id : null

  # Network configuration
  multi_az               = var.multi_az
  db_subnet_group_name   = var.create_db_subnet_group ? aws_db_subnet_group.this[0].name : var.db_subnet_group_name
  vpc_security_group_ids = var.vpc_security_group_ids
  publicly_accessible    = var.publicly_accessible
  availability_zone      = var.multi_az ? null : var.availability_zone

  # Parameter and option groups
  parameter_group_name = var.create_parameter_group ? aws_db_parameter_group.this[0].name : var.parameter_group_name
  option_group_name    = var.create_option_group ? aws_db_option_group.this[0].name : var.option_group_name

  # Backup configuration
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  copy_tags_to_snapshot  = var.copy_tags_to_snapshot

  # CloudWatch logs
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  # Enhanced monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? (
    var.create_monitoring_role ? aws_iam_role.enhanced_monitoring[0].arn : var.monitoring_role_arn
  ) : null

  # Performance Insights
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled && var.performance_insights_kms_key_id != null ? var.performance_insights_kms_key_id : null
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  # Upgrades and maintenance
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  allow_major_version_upgrade = var.allow_major_version_upgrade
  apply_immediately          = var.apply_immediately
  blue_green_update {
    enabled = var.enable_blue_green_update
  }

  # Deletion protection
  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # IAM database authentication
  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  # Domain join (for SQL Server)
  domain               = var.domain
  domain_iam_role_name = var.domain_iam_role_name

  # Character set
  character_set_name = var.character_set_name

  # Network type
  network_type = var.network_type

  tags = merge(
    local.common_tags,
    {
      Name = var.identifier
    }
  )

  lifecycle {
    ignore_changes = [
      password,  # Ignore password changes to prevent recreation
      final_snapshot_identifier  # Timestamp-based, will always differ
    ]
  }
}

################################################################################
# Read Replicas
################################################################################

resource "aws_db_instance" "replica" {
  for_each = var.read_replicas

  identifier     = "${var.identifier}-replica-${each.key}"
  replicate_source_db = aws_db_instance.this.identifier

  # Override primary instance settings
  instance_class = lookup(each.value, "instance_class", var.instance_class)
  
  # Storage (inherited from primary, but can override some)
  max_allocated_storage = lookup(each.value, "max_allocated_storage", var.max_allocated_storage)
  storage_type          = lookup(each.value, "storage_type", var.storage_type)
  iops                  = lookup(each.value, "iops", var.iops)

  # Multi-AZ for replica
  multi_az = lookup(each.value, "multi_az", false)
  
  # Availability zone for replica (if not multi-AZ)
  availability_zone = lookup(each.value, "multi_az", false) ? null : lookup(each.value, "availability_zone", null)

  # Monitoring
  monitoring_interval = lookup(each.value, "monitoring_interval", var.monitoring_interval)
  monitoring_role_arn = lookup(each.value, "monitoring_interval", var.monitoring_interval) > 0 ? (
    var.create_monitoring_role ? aws_iam_role.enhanced_monitoring[0].arn : var.monitoring_role_arn
  ) : null

  # Performance Insights
  performance_insights_enabled = lookup(each.value, "performance_insights_enabled", var.performance_insights_enabled)
  performance_insights_kms_key_id = lookup(each.value, "performance_insights_enabled", var.performance_insights_enabled) && var.performance_insights_kms_key_id != null ? var.performance_insights_kms_key_id : null

  # Maintenance
  auto_minor_version_upgrade = lookup(each.value, "auto_minor_version_upgrade", var.auto_minor_version_upgrade)
  apply_immediately          = lookup(each.value, "apply_immediately", false)

  # Promotion
  publicly_accessible = lookup(each.value, "publicly_accessible", false)
  
  # VPC security groups (can override)
  vpc_security_group_ids = lookup(each.value, "vpc_security_group_ids", var.vpc_security_group_ids)

  # Deletion
  skip_final_snapshot = lookup(each.value, "skip_final_snapshot", true)

  tags = merge(
    local.common_tags,
    lookup(each.value, "tags", {}),
    {
      Name = "${var.identifier}-replica-${each.key}"
      Role = "read-replica"
    }
  )

  depends_on = [aws_db_instance.this]
}

################################################################################
# Secrets Manager Secret for Database Credentials (Optional)
################################################################################

resource "aws_secretsmanager_secret" "db_credentials" {
  count = var.store_master_password_in_secrets_manager && !var.manage_master_user_password ? 1 : 0

  name        = "${var.identifier}-credentials"
  description = "Database credentials for ${var.identifier}"
  kms_key_id  = var.secrets_manager_kms_key_id

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  count = var.store_master_password_in_secrets_manager && !var.manage_master_user_password ? 1 : 0

  secret_id = aws_secretsmanager_secret.db_credentials[0].id
  secret_string = jsonencode({
    username = var.master_username
    password = var.master_password
    engine   = var.engine
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.database_name
    endpoint = aws_db_instance.this.endpoint
  })
}
