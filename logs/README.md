# Logs Directory

## 📋 Overview

The `logs/` directory serves as the centralized location for capturing runtime execution logs from automated deployment and infrastructure management operations. This directory is essential for auditing, troubleshooting, and maintaining a historical record of all infrastructure changes.

## 🎯 Purpose

This directory automatically stores timestamped log files generated during:

- **Deployment Operations**: Full infrastructure deployments across layers
- **Destruction Operations**: Infrastructure teardown and resource cleanup
- **Terraform Executions**: Init, plan, apply, and destroy operations
- **Script Executions**: Any automated operations performed by deployment scripts

## 📝 Log File Naming Convention

Log files follow a standardized naming pattern for easy identification and retrieval:

```
<operation>-<environment>-<timestamp>.log
```

### Examples:
- `deploy-dev-20241014-143022.log` - Development environment deployment
- `deploy-prod-20241014-090000.log` - Production deployment
- `destroy-qa-20241014-160045.log` - QA environment destruction

### Components:
- **Operation**: `deploy` or `destroy`
- **Environment**: `dev`, `qa`, `uat`, or `prod`
- **Timestamp**: `YYYYMMDD-HHMMSS` format

## 🔍 What's Logged

Each log file captures comprehensive details including:

### Terraform Operations
- Backend initialization and configuration
- State file operations
- Resource planning output
- Apply/destroy execution results
- Provider interactions
- Module executions

### Script Execution Details
- Environment validation
- AWS credential verification
- Layer-by-layer deployment progress
- Success/failure indicators
- Error messages and stack traces
- Timing information

### Infrastructure Changes
- Resources created, modified, or destroyed
- Configuration updates
- Dependency resolution
- Output values

## 📂 Directory Management

### Automatic Creation
The logs directory is automatically created by deployment scripts if it doesn't exist:

```bash
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
```

### Version Control
Log files are **excluded from version control** (`.gitignore`):
```
# Log files
*.log
```

This is intentional because:
- Log files contain environment-specific runtime data
- They can grow large over time
- They may contain sensitive information
- They're ephemeral operational artifacts

### Retention
Log files are retained locally but not committed to the repository. Consider implementing a retention policy:

**Recommended Retention Strategy:**
- **Development/QA**: 30 days
- **UAT**: 60 days  
- **Production**: 90+ days (or as per compliance requirements)

## 🛠️ Usage Examples

### Viewing the Latest Deployment Log
```bash
# View the most recent deployment log
ls -lt logs/deploy-*.log | head -1 | xargs cat

# Or with tail for live monitoring
tail -f logs/deploy-dev-$(date +%Y%m%d)*.log
```

### Searching Logs for Errors
```bash
# Find all errors across logs
grep -i "error" logs/*.log

# Search for specific resource failures
grep -i "failed to create" logs/deploy-prod-*.log
```

### Analyzing Deployment Duration
```bash
# Check timestamps in a specific log
grep -E "Started|Completed|Duration" logs/deploy-prod-20241014-090000.log
```

### Filtering by Environment
```bash
# View all production deployments
ls -lh logs/deploy-prod-*.log

# View all dev environment operations
ls -lh logs/*-dev-*.log
```

## 🔐 Security Considerations

### Sensitive Information
Logs may contain:
- AWS account IDs
- Resource ARNs and identifiers
- Configuration values
- IP addresses and network details

**Best Practices:**
- ✅ Restrict file permissions: `chmod 600 logs/*.log`
- ✅ Never commit log files to version control
- ✅ Implement log rotation and secure deletion
- ✅ Review logs before sharing

### Access Control
```bash
# Set restrictive permissions on the logs directory
chmod 700 logs/

# Set restrictive permissions on log files
find logs/ -type f -name "*.log" -exec chmod 600 {} \;
```

## 📊 Log Analysis

### Troubleshooting Deployment Failures

When a deployment fails, logs provide crucial debugging information:

1. **Identify the Failed Layer**
   ```bash
   grep "Failed to" logs/deploy-prod-20241014-090000.log
   ```

2. **Extract Terraform Error Messages**
   ```bash
   grep -A 5 "Error:" logs/deploy-prod-20241014-090000.log
   ```

3. **Check Resource Dependencies**
   ```bash
   grep "dependency" logs/deploy-prod-20241014-090000.log
   ```

### Success Verification
```bash
# Verify all layers deployed successfully
grep "Successfully deployed" logs/deploy-prod-20241014-090000.log
```

## 🔄 Log Rotation

Consider implementing automated log rotation to manage disk space:

### Using logrotate (Linux/macOS)
Create `/etc/logrotate.d/terraform-aws`:
```
/Users/diego/terraform-aws-enterprise/logs/*.log {
    daily
    rotate 90
    compress
    delaycompress
    missingok
    notifempty
    create 0600 diego staff
}
```

### Manual Cleanup Script
```bash
#!/bin/bash
# Clean logs older than 90 days
find /Users/diego/terraform-aws-enterprise/logs -name "*.log" -mtime +90 -delete
```

## 📈 Integration with Monitoring

### Shipping Logs to External Systems

For enterprise environments, consider shipping logs to:

- **CloudWatch Logs**: For centralized AWS logging
  ```bash
  aws logs put-log-events --log-group-name /terraform/deployments \
    --log-stream-name $HOSTNAME \
    --log-events file://logs/deploy-prod-20241014-090000.log
  ```

- **ELK Stack**: For advanced log analytics
- **Splunk**: For enterprise SIEM integration
- **S3**: For long-term archival
  ```bash
  aws s3 cp logs/ s3://my-terraform-logs-bucket/$(date +%Y/%m/)/ --recursive
  ```

## 🔧 Maintenance

### Disk Space Management
Monitor log directory size:
```bash
# Check directory size
du -sh logs/

# Count log files
ls -1 logs/*.log | wc -l

# Find largest log files
du -h logs/*.log | sort -hr | head -10
```

### Archive Old Logs
```bash
# Archive logs older than 30 days
tar -czf logs-archive-$(date +%Y%m).tar.gz \
  $(find logs/ -name "*.log" -mtime +30)
  
# Then delete archived logs
find logs/ -name "*.log" -mtime +30 -delete
```

## 📋 Related Documentation

- **Deployment Guide**: `DEPLOYMENT_RUNBOOK.md`
- **Troubleshooting**: `docs/TROUBLESHOOTING.md`
- **Main README**: `README.md`
- **Operations Runbook**: `docs/RUNBOOK.md`

## 🆘 Support

If you encounter issues with logging:

1. Verify script permissions: `chmod +x deploy.sh destroy.sh`
2. Check disk space: `df -h`
3. Verify directory permissions: `ls -la logs/`
4. Review the deployment scripts: `deploy.sh` and `destroy.sh`

## 📝 Notes

- Logs are created automatically; no manual intervention required
- Each deployment/destruction creates a new timestamped log file
- Logs capture both stdout and stderr from Terraform operations
- The directory structure is flat (no subdirectories)
- Log format is plain text for easy parsing and analysis

---

**Last Updated**: October 14, 2025  
**Maintained By**: DevOps/SRE Team
