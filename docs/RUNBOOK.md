# Operational Runbook

## Overview

This runbook provides step-by-step procedures for common operational tasks in the AWS infrastructure.

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [Deployment Procedures](#deployment-procedures)
3. [Incident Response](#incident-response)
4. [Maintenance Procedures](#maintenance-procedures)
5. [Backup and Recovery](#backup-and-recovery)
6. [Scaling Operations](#scaling-operations)
7. [Security Operations](#security-operations)

## Daily Operations

### Morning Health Check

**Frequency:** Daily, 9:00 AM

**Steps:**
```bash
#!/bin/bash
# Daily health check script

echo "=== AWS Infrastructure Health Check ==="
echo "Date: $(date)"
echo ""

# Check VPC status
echo "1. VPC Status:"
aws ec2 describe-vpcs \
  --filters "Name=tag:Environment,Values=prod" \
  --query 'Vpcs[*].[VpcId,State,CidrBlock]' \
  --output table

# Check NAT Gateway health
echo "2. NAT Gateway Status:"
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available" \
  --query 'NatGateways[*].[NatGatewayId,State,VpcId]' \
  --output table

# Check RDS instances
echo "3. RDS Database Status:"
aws rds describe-db-instances \
  --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus,AvailabilityZone]' \
  --output table

# Check ECS services
echo "4. ECS Service Status:"
aws ecs list-clusters --query 'clusterArns' --output text | \
while read cluster; do
  echo "Cluster: $cluster"
  aws ecs list-services --cluster $cluster \
    --query 'serviceArns' --output text | \
  while read service; do
    aws ecs describe-services --cluster $cluster --services $service \
      --query 'services[*].[serviceName,status,runningCount,desiredCount]' \
      --output table
  done
done

# Check ALB health
echo "5. Load Balancer Health:"
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[*].[LoadBalancerName,State.Code,DNSName]' \
  --output table

# Check CloudWatch alarms
echo "6. Active Alarms:"
aws cloudwatch describe-alarms \
  --state-value ALARM \
  --query 'MetricAlarms[*].[AlarmName,StateValue,StateReason]' \
  --output table

# Check recent errors in CloudWatch Logs
echo "7. Recent Application Errors:"
aws logs filter-log-events \
  --log-group-name "/aws/application/enterprise-prod" \
  --start-time $(($(date +%s) - 3600))000 \
  --filter-pattern "ERROR" \
  --query 'events[*].[timestamp,message]' \
  --output table | head -20

echo ""
echo "=== Health Check Complete ==="
```

**Expected Results:**
- All VPCs in "available" state
- NAT Gateways "available"
- RDS instances "available"
- ECS services running count = desired count
- No ALARM state CloudWatch alarms
- Minimal ERROR logs

**Actions on Failures:**
- Document issues in incident tracking system
- Follow relevant incident response procedures
- Escalate if critical services affected

### Monitor Resource Usage

**Frequency:** Every 4 hours

```bash
#!/bin/bash
# Resource utilization check

# ECS cluster utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=enterprise-prod-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# RDS CPU and connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=enterprise-prod-db \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# S3 bucket sizes
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name BucketSizeBytes \
  --dimensions Name=BucketName,Value=enterprise-prod-app \
    Name=StorageType,Value=StandardStorage \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Average
```

## Deployment Procedures

### Standard Deployment (Non-Production)

**Pre-Deployment:**
```bash
# 1. Create deployment branch
git checkout -b deploy/feature-name

# 2. Run validation
terraform validate
terraform fmt -check -recursive
tflint
tfsec .

# 3. Create deployment plan
cd layers/<layer>/environments/dev
terraform plan -var-file=terraform.tfvars -out=tfplan

# 4. Review plan with team
# Share plan output in Slack #deployments channel

# 5. Get approval
# At least one +1 from team member
```

**Deployment:**
```bash
# 1. Set environment
export AWS_PROFILE=dev

# 2. Apply changes
terraform apply tfplan

# 3. Verify deployment
./scripts/verify-deployment.sh dev

# 4. Monitor for 15 minutes
watch -n 30 'aws ecs describe-services --cluster enterprise-dev-cluster --services app'

# 5. Document deployment
# Update deployment log in wiki
```

**Post-Deployment:**
```bash
# 1. Run smoke tests
curl -I https://dev.example.com/health

# 2. Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/enterprise-dev-alb/... \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average

# 3. Update documentation
git add docs/
git commit -m "docs: update after deployment"
git push origin deploy/feature-name

# 4. Clean up
rm tfplan
```

### Production Deployment

**Requirements:**
- [ ] Change request approved (ticket #)
- [ ] Tested in dev and QA environments
- [ ] Rollback plan documented
- [ ] Team notified 24 hours in advance
- [ ] Deployment window scheduled
- [ ] On-call engineer identified

**Pre-Production Checklist:**
```bash
# 1. Verify no drift in production
cd layers/<layer>/environments/prod
terraform plan -var-file=terraform.tfvars

# 2. Create database backup
aws rds create-db-snapshot \
  --db-instance-identifier enterprise-prod-db \
  --db-snapshot-identifier pre-deploy-$(date +%Y%m%d%H%M)

# 3. Export current state
terraform state pull > state-backup-$(date +%Y%m%d%H%M).json

# 4. Document current metrics baseline
./scripts/capture-baseline-metrics.sh prod
```

**Production Deployment Window:**
```bash
# 1. Announce deployment start
# Slack: @channel Deployment starting for <change-description>

# 2. Enable maintenance mode (if applicable)
aws ecs update-service \
  --cluster enterprise-prod-cluster \
  --service maintenance-page \
  --desired-count 1

# 3. Scale down application (for zero-downtime, skip this)
# aws ecs update-service --cluster ... --desired-count 0

# 4. Apply Terraform changes
export AWS_PROFILE=prod
terraform apply -var-file=terraform.tfvars

# 5. Verify infrastructure
./scripts/verify-deployment.sh prod

# 6. Scale up application
aws ecs update-service \
  --cluster enterprise-prod-cluster \
  --service app-service \
  --desired-count 3

# 7. Wait for healthy targets
aws elbv2 describe-target-health \
  --target-group-arn <TG_ARN> \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]'

# 8. Disable maintenance mode
aws ecs update-service \
  --cluster enterprise-prod-cluster \
  --service maintenance-page \
  --desired-count 0

# 9. Monitor for 30 minutes
watch -n 30 './scripts/check-health.sh prod'

# 10. Announce completion
# Slack: @channel Deployment complete. Monitoring for issues.
```

**Rollback Procedure:**
```bash
# If issues detected within 30 minutes

# 1. Announce rollback
# Slack: @channel ROLLBACK initiated due to <reason>

# 2. Restore previous Terraform state
terraform state push state-backup-<timestamp>.json

# 3. Reapply previous configuration
terraform apply -auto-approve

# 4. Verify rollback
./scripts/verify-deployment.sh prod

# 5. Document incident
# Create post-mortem document
```

## Incident Response

### Severity Levels

**P0 - Critical (Production Down)**
- Response Time: Immediate
- Notification: Page on-call, notify leadership
- Example: Complete site outage, data breach

**P1 - High (Degraded Service)**
- Response Time: 15 minutes
- Notification: Alert on-call, notify team
- Example: High error rates, slow response times

**P2 - Medium (Partial Impact)**
- Response Time: 1 hour
- Notification: Team Slack channel
- Example: Single AZ issues, non-critical feature down

**P3 - Low (Minimal Impact)**
- Response Time: Next business day
- Notification: Ticket system
- Example: Monitoring alerts, non-production issues

### P0 Incident Response

**Initial Response (0-5 minutes):**
```bash
# 1. Acknowledge incident
# Update status page: https://status.company.com

# 2. Form incident response team
# Incident Commander, Technical Lead, Communications Lead

# 3. Create incident channel
# Slack: #incident-<timestamp>

# 4. Quick assessment
./scripts/quick-diagnostics.sh prod
```

**Investigation (5-15 minutes):**
```bash
# Check recent changes
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=UpdateService \
  --start-time $(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --max-results 50

# Check application logs
aws logs tail /aws/application/enterprise-prod --follow --since 1h

# Check system metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=LoadBalancer,Value=... \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum
```

**Resolution Actions:**
```bash
# Common fixes based on issue type:

# 1. Application Crash Loop
aws ecs update-service \
  --cluster enterprise-prod-cluster \
  --service app-service \
  --force-new-deployment

# 2. Database Connection Issues
# Check security groups
aws ec2 describe-security-groups --group-ids <RDS_SG_ID>
# Verify RDS status
aws rds describe-db-instances --db-instance-identifier enterprise-prod-db

# 3. High CPU/Memory
# Scale up ECS service
aws ecs update-service \
  --cluster enterprise-prod-cluster \
  --service app-service \
  --desired-count 6

# 4. Load Balancer Issues
# Check target health
aws elbv2 describe-target-health --target-group-arn <TG_ARN>
```

**Post-Incident (After Resolution):**
```bash
# 1. Update status page
# Mark incident as resolved

# 2. Document timeline
# Create incident report in wiki

# 3. Schedule post-mortem
# Within 48 hours, all incident team members

# 4. Implement preventive measures
# Create tickets for improvements
```

## Maintenance Procedures

### RDS Maintenance

**Minor Version Upgrade:**
```bash
# 1. Schedule maintenance window
aws rds modify-db-instance \
  --db-instance-identifier enterprise-prod-db \
  --preferred-maintenance-window sun:04:00-sun:05:00 \
  --apply-immediately false

# 2. Create snapshot before upgrade
aws rds create-db-snapshot \
  --db-instance-identifier enterprise-prod-db \
  --db-snapshot-identifier pre-upgrade-$(date +%Y%m%d)

# 3. Apply upgrade (during maintenance window)
aws rds modify-db-instance \
  --db-instance-identifier enterprise-prod-db \
  --engine-version 15.5 \
  --apply-immediately true

# 4. Monitor upgrade
watch -n 30 'aws rds describe-db-instances \
  --db-instance-identifier enterprise-prod-db \
  --query "DBInstances[0].[DBInstanceStatus,EngineVersion]"'

# 5. Verify post-upgrade
psql -h <RDS_ENDPOINT> -U admin -d dbname -c "SELECT version();"
```

### Certificate Renewal

**ACM Certificate:**
```bash
# 1. Request new certificate
aws acm request-certificate \
  --domain-name example.com \
  --subject-alternative-names *.example.com \
  --validation-method DNS

# 2. Add validation DNS records to Route53
# (ACM provides DNS records to add)

# 3. Wait for validation
aws acm describe-certificate \
  --certificate-arn <CERT_ARN> \
  --query 'Certificate.Status'

# 4. Update load balancer listener
aws elbv2 modify-listener \
  --listener-arn <LISTENER_ARN> \
  --certificates CertificateArn=<NEW_CERT_ARN>

# 5. Verify HTTPS
curl -I https://example.com
```

### ECS Task Definition Update

**Zero-Downtime Update:**
```bash
# 1. Register new task definition
aws ecs register-task-definition \
  --cli-input-json file://task-definition.json

# 2. Update service with new task definition
aws ecs update-service \
  --cluster enterprise-prod-cluster \
  --service app-service \
  --task-definition app-task:5 \
  --deployment-configuration \
    "maximumPercent=200,minimumHealthyPercent=100"

# 3. Monitor deployment
aws ecs describe-services \
  --cluster enterprise-prod-cluster \
  --services app-service \
  --query 'services[0].deployments[*].[status,desiredCount,runningCount]'

# 4. Wait for deployment completion
aws ecs wait services-stable \
  --cluster enterprise-prod-cluster \
  --services app-service
```

## Backup and Recovery

### Database Backup

**Manual Backup:**
```bash
# 1. Create RDS snapshot
aws rds create-db-snapshot \
  --db-instance-identifier enterprise-prod-db \
  --db-snapshot-identifier manual-$(date +%Y%m%d%H%M)

# 2. Wait for snapshot completion
aws rds wait db-snapshot-completed \
  --db-snapshot-identifier manual-$(date +%Y%m%d%H%M)

# 3. Export snapshot to S3 (for long-term storage)
aws rds start-export-task \
  --export-task-identifier export-$(date +%Y%m%d) \
  --source-arn arn:aws:rds:region:account:snapshot:manual-$(date +%Y%m%d%H%M) \
  --s3-bucket-name enterprise-prod-backups \
  --iam-role-arn arn:aws:iam::account:role/RDSExportRole
```

**Database Restore:**
```bash
# 1. List available snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier enterprise-prod-db \
  --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime]' \
  --output table

# 2. Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier enterprise-prod-db-restored \
  --db-snapshot-identifier manual-20250101 \
  --db-subnet-group-name enterprise-prod-db-subnet-group \
  --vpc-security-group-ids sg-xxxxx

# 3. Wait for restore completion
aws rds wait db-instance-available \
  --db-instance-identifier enterprise-prod-db-restored

# 4. Update application connection string
# Or restore to original instance after verification
```

### Infrastructure State Backup

**Automated Backup Script:**
```bash
#!/bin/bash
# Save to scripts/backup-terraform-state.sh

ENVIRONMENTS="dev qa uat prod"
LAYERS="networking security dns database storage compute monitoring"
BACKUP_BUCKET="terraform-state-backups"

for env in $ENVIRONMENTS; do
  for layer in $LAYERS; do
    echo "Backing up $env - $layer"
    
    # Pull current state
    cd layers/$layer/environments/$env
    terraform state pull > state.json
    
    # Upload to S3 with timestamp
    aws s3 cp state.json \
      s3://$BACKUP_BUCKET/$env/$layer/state-$(date +%Y%m%d%H%M).json
    
    rm state.json
    cd -
  done
done
```

## Scaling Operations

### Scale ECS Service

**Manual Scaling:**
```bash
# Scale up
aws ecs update-service \
  --cluster enterprise-prod-cluster \
  --service app-service \
  --desired-count 6

# Scale down
aws ecs update-service \
  --cluster enterprise-prod-cluster \
  --service app-service \
  --desired-count 2
```

**Auto Scaling Setup:**
```bash
# Register scalable target
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/enterprise-prod-cluster/app-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 2 \
  --max-capacity 10

# Create scaling policy
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/enterprise-prod-cluster/app-service \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name cpu-scaling-policy \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://scaling-policy.json
```

### Scale RDS Instance

```bash
# 1. Create snapshot before scaling
aws rds create-db-snapshot \
  --db-instance-identifier enterprise-prod-db \
  --db-snapshot-identifier pre-scale-$(date +%Y%m%d)

# 2. Modify instance class
aws rds modify-db-instance \
  --db-instance-identifier enterprise-prod-db \
  --db-instance-class db.r5.xlarge \
  --apply-immediately true

# 3. Monitor modification
watch -n 30 'aws rds describe-db-instances \
  --db-instance-identifier enterprise-prod-db \
  --query "DBInstances[0].[DBInstanceStatus,DBInstanceClass]"'
```

## Security Operations

### Rotate Access Keys

```bash
# 1. Create new access key
aws iam create-access-key --user-name service-user

# 2. Update applications with new keys
# Deploy new keys via AWS Secrets Manager

# 3. Test applications
curl -I https://api.example.com/health

# 4. Delete old access key
aws iam delete-access-key \
  --user-name service-user \
  --access-key-id AKIA...OLD...KEY
```

### Security Audit

**Monthly Security Review:**
```bash
# 1. Check for unused IAM users
aws iam list-users --query 'Users[?PasswordLastUsed<`2024-01-01`]'

# 2. Review security groups
aws ec2 describe-security-groups \
  --filters "Name=ip-permission.cidr,Values=0.0.0.0/0" \
  --query 'SecurityGroups[*].[GroupId,GroupName]'

# 3. Check S3 bucket policies
aws s3api list-buckets --query 'Buckets[*].Name' --output text | \
while read bucket; do
  echo "Bucket: $bucket"
  aws s3api get-bucket-acl --bucket $bucket
done

# 4. Review CloudTrail logs
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=DeleteBucket \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S)
```

## Contact Information

**On-Call Schedule:**
- Check PagerDuty for current on-call engineer
- Escalation: +1-555-0100

**Team Contacts:**
- Platform Team: platform-team@company.com
- Security Team: security@company.com
- DevOps Lead: devops-lead@company.com

**External Support:**
- AWS Support: https://console.aws.amazon.com/support/
- Emergency: +1-206-266-4064

## Document Updates

This runbook should be reviewed and updated:
- After each major incident
- Quarterly for accuracy
- When procedures change
- When new services are added

Last Updated: 2025-01-05
Version: 1.0
