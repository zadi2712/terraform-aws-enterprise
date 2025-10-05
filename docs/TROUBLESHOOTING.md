# Troubleshooting Guide

## Overview

This guide provides solutions to common issues encountered when working with the Terraform AWS infrastructure.

## Table of Contents

1. [Terraform State Issues](#terraform-state-issues)
2. [Network Connectivity](#network-connectivity)
3. [Resource Creation Failures](#resource-creation-failures)
4. [Authentication and Permissions](#authentication-and-permissions)
5. [Performance Issues](#performance-issues)
6. [Cost Optimization](#cost-optimization)

## Terraform State Issues

### Issue: State Lock Error

**Symptom:**
```
Error: Error acquiring the state lock
Lock Info:
  ID:        abc123...
  Path:      terraform-state-dev-123456789/layers/networking/dev/terraform.tfstate
  Operation: OperationTypeApply
  Who:       user@hostname
```

**Cause:** Previous terraform operation didn't release the lock (crashed, interrupted)

**Solution:**
```bash
# 1. Verify no one is actually running terraform
terraform force-unlock <LOCK_ID>

# 2. If problem persists, check DynamoDB
aws dynamodb scan \
  --table-name terraform-state-lock-dev \
  --filter-expression "LockID = :lockid" \
  --expression-attribute-values '{":lockid":{"S":"<LOCK_ID>"}}'

# 3. Manual unlock (last resort)
aws dynamodb delete-item \
  --table-name terraform-state-lock-dev \
  --key '{"LockID":{"S":"<LOCK_ID>"}}'
```

### Issue: State File Corruption

**Symptom:**
```
Error: Failed to load state: state snapshot was created by Terraform v1.x.x,
which is newer than current v1.x.x
```

**Solution:**
```bash
# 1. Pull current state
terraform state pull > terraform.tfstate.backup

# 2. Use S3 versioning to restore previous version
aws s3api list-object-versions \
  --bucket terraform-state-dev-123456789 \
  --prefix layers/networking/dev/terraform.tfstate

# 3. Download specific version
aws s3api get-object \
  --bucket terraform-state-dev-123456789 \
  --key layers/networking/dev/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate

# 4. Push restored state
terraform state push terraform.tfstate
```

### Issue: State Drift Detected

**Symptom:**
```
Note: Objects have changed outside of Terraform
```

**Solution:**
```bash
# 1. Review the drift
terraform plan -refresh-only

# 2. Update state to match reality
terraform apply -refresh-only

# 3. If changes are unwanted, reapply configuration
terraform apply
```

## Network Connectivity

### Issue: Cannot Connect to RDS from EC2

**Checklist:**
```bash
# 1. Verify security group rules
aws ec2 describe-security-groups \
  --group-ids <RDS_SG_ID> \
  --query 'SecurityGroups[0].IpPermissions'

# 2. Check NACL rules
aws ec2 describe-network-acls \
  --filters "Name=vpc-id,Values=<VPC_ID>" \
  --query 'NetworkAcls[*].Entries'

# 3. Test connection from EC2
nc -zv <RDS_ENDPOINT> 5432

# 4. Check route tables
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=<VPC_ID>"
```

**Common Causes:**
- Security group not allowing traffic from EC2 subnet
- NACL blocking traffic
- Wrong subnet (database in different AZ)
- DNS resolution issues

### Issue: NAT Gateway Not Working

**Symptom:** Private instances cannot reach internet

**Diagnosis:**
```bash
# 1. Check NAT Gateway status
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=<VPC_ID>" \
  --query 'NatGateways[*].[NatGatewayId,State]'

# 2. Verify route table has NAT route
aws ec2 describe-route-tables \
  --filter "Name=vpc-id,Values=<VPC_ID>" \
  --query 'RouteTables[*].Routes'

# 3. Check Elastic IP association
aws ec2 describe-addresses \
  --filters "Name=network-interface-id,Values=<NAT_ENI_ID>"
```

**Solution:**
```terraform
# Ensure proper dependencies in your code
resource "aws_nat_gateway" "main" {
  # ...
  depends_on = [aws_internet_gateway.main]
}
```

### Issue: VPC Endpoint Connection Timeout

**Symptom:** Cannot access S3/DynamoDB via VPC endpoint

**Solution:**
```bash
# 1. Verify endpoint exists
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=<VPC_ID>"

# 2. Check route table associations
aws ec2 describe-vpc-endpoints \
  --vpc-endpoint-ids <ENDPOINT_ID> \
  --query 'VpcEndpoints[0].RouteTableIds'

# 3. Test S3 access
aws s3 ls --region us-east-1

# 4. Check VPC endpoint policy
aws ec2 describe-vpc-endpoints \
  --vpc-endpoint-ids <ENDPOINT_ID> \
  --query 'VpcEndpoints[0].PolicyDocument'
```

## Resource Creation Failures

### Issue: RDS Creation Timeout

**Symptom:**
```
Error: waiting for RDS DB Instance creation: timeout while waiting for state
```

**Causes:**
- Large instance taking longer than expected
- Multi-AZ deployment delays
- Backup restoration timeout

**Solution:**
```terraform
# Increase timeout in module
resource "aws_db_instance" "this" {
  # ...
  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }
}
```

### Issue: ECS Service Fails to Start

**Common Issues:**
1. **No Available IPs in Subnet**
```bash
# Check available IPs
aws ec2 describe-subnets \
  --subnet-ids <SUBNET_ID> \
  --query 'Subnets[0].AvailableIpAddressCount'
```

2. **ECR Image Pull Failure**
```bash
# Verify ECR permissions
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <ACCOUNT>.dkr.ecr.us-east-1.amazonaws.com

# Check image exists
aws ecr describe-images \
  --repository-name <REPO_NAME> \
  --image-ids imageTag=latest
```

3. **Insufficient Task Execution Role Permissions**
```bash
# Test IAM role
aws sts assume-role \
  --role-arn arn:aws:iam::<ACCOUNT>:role/ecs-task-execution \
  --role-session-name test
```

### Issue: ALB Target Health Checks Failing

**Diagnosis:**
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <TG_ARN>

# Common reasons:
# - Health check path returns non-2xx
# - Security group blocking health check traffic
# - Application not listening on health check port
```

**Solution:**
```terraform
resource "aws_lb_target_group" "this" {
  # ...
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-299"
    path                = "/health"
    timeout             = 5
    unhealthy_threshold = 3
  }
}
```

## Authentication and Permissions

### Issue: Access Denied Errors

**Symptom:**
```
Error: Error creating VPC: UnauthorizedOperation: You are not authorized
to perform this operation.
```

**Solutions:**
```bash
# 1. Verify AWS credentials
aws sts get-caller-identity

# 2. Check IAM permissions
aws iam get-user-policy \
  --user-name terraform-user \
  --policy-name terraform-policy

# 3. Test specific permission
aws ec2 create-vpc --cidr-block 10.99.0.0/16 --dry-run
```

### Issue: AssumeRole Failed

**Symptom:**
```
Error: error configuring Terraform AWS Provider: error validating provider
credentials: error calling sts:GetCallerIdentity: operation error STS: GetCallerIdentity
```

**Solution:**
```bash
# 1. Verify role exists
aws iam get-role --role-name TerraformDeploymentRole

# 2. Check trust policy
aws iam get-role --role-name TerraformDeploymentRole \
  --query 'Role.AssumeRolePolicyDocument'

# 3. Test assume role
aws sts assume-role \
  --role-arn arn:aws:iam::<ACCOUNT>:role/TerraformDeploymentRole \
  --role-session-name test-session
```

## Performance Issues

### Issue: Terraform Plan Takes Too Long

**Optimization Strategies:**
```bash
# 1. Target specific resources
terraform plan -target=module.vpc

# 2. Parallelize operations
terraform plan -parallelism=20

# 3. Reduce refresh operations
terraform plan -refresh=false

# 4. Use partial configurations
terraform plan -var-file=minimal.tfvars
```

### Issue: RDS High CPU

**Diagnosis:**
```bash
# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=<DB_ID> \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-02T00:00:00Z \
  --period 3600 \
  --statistics Average

# Enable Performance Insights
aws rds modify-db-instance \
  --db-instance-identifier <DB_ID> \
  --enable-performance-insights
```

**Solutions:**
- Scale up instance size
- Add read replicas
- Enable query caching
- Optimize slow queries

### Issue: ECS Service High Memory

**Diagnosis:**
```bash
# Check Container Insights
aws cloudwatch get-metric-statistics \
  --namespace ECS/ContainerInsights \
  --metric-name MemoryUtilized \
  --dimensions Name=ServiceName,Value=<SERVICE> Name=ClusterName,Value=<CLUSTER>
```

**Solutions:**
```terraform
# Increase task memory
resource "aws_ecs_task_definition" "app" {
  memory = "2048"  # Increased from 1024
  # ...
}
```

## Cost Optimization

### Issue: Unexpected High Costs

**Investigation:**
```bash
# 1. Check Cost Explorer
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# 2. Check NAT Gateway costs (often culprit)
aws ec2 describe-nat-gateways \
  --query 'NatGateways[*].[NatGatewayId,State]'

# 3. Check data transfer costs
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name BytesOutToSource \
  --dimensions Name=NatGatewayId,Value=<NAT_ID>
```

**Optimization Steps:**
1. Use single NAT for non-prod environments
2. Enable VPC endpoints for S3/DynamoDB
3. Use CloudFront for static content
4. Right-size RDS instances
5. Delete unused EBS volumes
6. Use Spot instances for non-critical workloads

### Issue: Over-Provisioned Resources

**Audit Script:**
```bash
#!/bin/bash
# Resource audit script

# Unused EBS volumes
aws ec2 describe-volumes \
  --filters Name=status,Values=available \
  --query 'Volumes[*].[VolumeId,Size,CreateTime]'

# Unused Elastic IPs
aws ec2 describe-addresses \
  --query 'Addresses[?AssociationId==`null`].[PublicIp,AllocationId]'

# Idle Load Balancers
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?State.Code==`active`].[LoadBalancerName,LoadBalancerArn]'

# RDS instances with low CPU
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=<DB_ID> \
  --statistics Average
```

## Emergency Procedures

### Complete Infrastructure Failure

**Recovery Steps:**
```bash
# 1. Check AWS Service Health
# https://status.aws.amazon.com/

# 2. Verify account status
aws iam get-account-summary

# 3. Check for recent changes
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=DeleteVpc \
  --max-results 50

# 4. Restore from state backup
terraform state pull > current-state.json
# Compare with S3 versioned state
# Restore if necessary

# 5. Redeploy critical infrastructure
./deploy-infrastructure.sh prod
```

### Data Loss Prevention

**Immediate Actions:**
```bash
# 1. Create snapshots
aws rds create-db-snapshot \
  --db-instance-identifier <DB_ID> \
  --db-snapshot-identifier emergency-snapshot-$(date +%Y%m%d%H%M)

# 2. Backup S3 buckets
aws s3 sync s3://production-bucket s3://backup-bucket

# 3. Export critical data
pg_dump -h <RDS_ENDPOINT> -U admin dbname > emergency-backup.sql
```

## Getting Help

### Escalation Path

1. **Check This Guide**: Review relevant sections
2. **Check AWS Documentation**: https://docs.aws.amazon.com/
3. **Review Terraform Docs**: https://registry.terraform.io/providers/hashicorp/aws
4. **Internal Wiki**: Check company knowledge base
5. **Team Slack**: #platform-engineering channel
6. **On-Call Engineer**: Page if production impact
7. **AWS Support**: Open support ticket if AWS service issue

### Useful Commands Reference

```bash
# Quick diagnostics
terraform validate                    # Validate configuration
terraform fmt -check -recursive      # Check formatting
terraform show                       # Show current state
terraform output                     # Show outputs
terraform state list                 # List resources in state
terraform graph | dot -Tpng > graph.png  # Visualize dependencies

# AWS CLI diagnostics
aws ec2 describe-vpcs                # List VPCs
aws ec2 describe-subnets             # List subnets
aws rds describe-db-instances        # List RDS instances
aws ecs list-clusters                # List ECS clusters
aws logs tail <LOG_GROUP>            # Tail CloudWatch logs
```

## Prevention Best Practices

1. **Always run terraform plan before apply**
2. **Use remote state with locking**
3. **Enable MFA for production accounts**
4. **Regular backups and testing**
5. **Monitor resource usage and costs**
6. **Document all manual changes**
7. **Use version control for all code**
8. **Test changes in dev first**
9. **Have rollback procedures ready**
10. **Regular security audits**

## Additional Resources

- [AWS Troubleshooting Guide](https://docs.aws.amazon.com/troubleshooting/)
- [Terraform Debugging](https://www.terraform.io/docs/internals/debugging.html)
- [AWS Support Plans](https://aws.amazon.com/premiumsupport/plans/)
- Internal Runbook (docs/RUNBOOK.md)
