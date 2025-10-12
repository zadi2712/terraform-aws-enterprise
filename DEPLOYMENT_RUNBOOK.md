# VPC Endpoints Deployment Runbook

**Document Version**: 1.0  
**Last Updated**: October 12, 2025  
**Deployment Type**: VPC Endpoints Infrastructure  
**Estimated Duration**: 2-4 hours per environment  
**Risk Level**: Medium (network changes, potential service disruption)

---

## 📋 Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Deployment Prerequisites](#deployment-prerequisites)
3. [Deployment Steps](#deployment-steps)
4. [Verification & Testing](#verification--testing)
5. [Rollback Procedures](#rollback-procedures)
6. [Post-Deployment Tasks](#post-deployment-tasks)
7. [Troubleshooting Guide](#troubleshooting-guide)
8. [Emergency Contacts](#emergency-contacts)

---

## 🎯 Deployment Overview

### What We're Deploying
- **VPC Endpoints Module**: Enterprise-grade AWS VPC endpoints infrastructure
- **20 VPC Endpoints Total**:
  - 18 Interface Endpoints (EC2, ECS, RDS, Lambda, etc.)
  - 2 Gateway Endpoints (S3, DynamoDB)
- **Security Groups**: Managed security group for all interface endpoints
- **DNS Resolution**: Private DNS enabled for all interface endpoints

### Why We're Deploying This
- **Security**: Eliminate public internet exposure for AWS API calls
- **Performance**: Reduce latency by 30% using AWS backbone network
- **Compliance**: Meet PCI-DSS and HIPAA requirements
- **Cost Optimization**: Reduce NAT Gateway data transfer costs

### Environments Affected
- ✅ **Phase 1**: Dev environment (Oct 14-15, 2025)
- ✅ **Phase 2**: QA environment (Oct 18-19, 2025)
- ✅ **Phase 3**: UAT environment (Oct 21-22, 2025)
- ✅ **Phase 4**: Production (Oct 25-26, 2025)

---

## ⚠️ Pre-Deployment Checklist

### 1. Team Readiness
- [ ] Deployment team members identified and available
- [ ] Change management ticket created and approved
- [ ] Stakeholders notified of deployment window
- [ ] Rollback team on standby
- [ ] Communication channels established (Slack, PagerDuty)

### 2. Documentation Review
- [ ] Review [VPC_ENDPOINTS_COMPLETION.md](./VPC_ENDPOINTS_COMPLETION.md)
- [ ] Review [modules/vpc-endpoints/README.md](./modules/vpc-endpoints/README.md)
- [ ] Review [layers/networking/README.md](./layers/networking/README.md)
- [ ] Review this deployment runbook with team

### 3. Access & Permissions
- [ ] AWS Console access confirmed
- [ ] AWS CLI configured with appropriate credentials
- [ ] Terraform Cloud/Enterprise access verified
- [ ] GitHub/GitLab repository access confirmed
- [ ] VPN connection established (if required)

### 4. Backup & State Management
- [ ] Current Terraform state backed up
- [ ] Existing VPC configuration documented
- [ ] Current routing tables exported
- [ ] Security group rules documented
- [ ] VPC Flow Logs enabled and verified

### 5. Environment Preparation
- [ ] Non-production environment selected for initial deployment
- [ ] Maintenance window scheduled (off-peak hours recommended)
- [ ] Application teams notified of potential brief connectivity changes
- [ ] Monitoring dashboards prepared
- [ ] Log aggregation confirmed operational

---

## 🔧 Deployment Prerequisites

### Required Tools & Versions
```bash
# Verify tool versions
terraform version  # Required: >= 1.5.0
aws --version      # Required: >= 2.x
git --version      # Required: >= 2.x
jq --version       # Recommended: >= 1.6
```

### AWS Account Requirements
- AWS Account ID: `<your-account-id>`
- Region: As specified in terraform.tfvars (typically us-east-1)
- VPC ID: Available from existing networking layer
- Subnet IDs: Private subnets must exist
- IAM Permissions:
  - ec2:CreateVpcEndpoint
  - ec2:DescribeVpcEndpoints
  - ec2:ModifyVpcEndpoint
  - ec2:DeleteVpcEndpoint
  - ec2:CreateSecurityGroup
  - ec2:AuthorizeSecurityGroupIngress
  - ec2:CreateTags

### Terraform Backend Setup
```bash
# Ensure S3 backend exists
aws s3 ls s3://your-terraform-state-bucket || aws s3 mb s3://your-terraform-state-bucket

# Ensure DynamoDB table exists for state locking
aws dynamodb describe-table --table-name terraform-state-lock || \
  aws dynamodb create-table \
    --table-name terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
```

---

## 🚀 Deployment Steps

### Phase 1: Code Preparation & Validation

#### Step 1.1: Clone/Update Repository
```bash
# Clone repository (if not already cloned)
git clone https://github.com/your-org/terraform-aws-enterprise.git
cd terraform-aws-enterprise

# Or update existing repository
cd terraform-aws-enterprise
git checkout main
git pull origin main

# Create deployment branch
git checkout -b vpc-endpoints-deployment-$(date +%Y%m%d)
```

#### Step 1.2: Format Terraform Code
```bash
# Format all Terraform files
terraform fmt -recursive modules/vpc-endpoints/
terraform fmt -recursive layers/networking/

# Verify formatting
git diff

# Commit formatting changes if any
git add -A
git commit -m "chore: format terraform files before deployment"
```

#### Step 1.3: Validate Module
```bash
# Navigate to VPC endpoints module
cd modules/vpc-endpoints

# Initialize module
terraform init

# Validate syntax
terraform validate

# Expected output: "Success! The configuration is valid."
```

### Phase 2: Dev Environment Deployment

#### Step 2.1: Prepare Dev Environment
```bash
# Navigate to dev environment
cd /Users/diego/terraform-aws-enterprise/layers/networking/environments/dev

# Review configuration
cat terraform.tfvars | grep -E "(project_name|environment|vpc_cidr|enable_vpc_endpoints)"

# Verify backend configuration
cat backend.conf
```

#### Step 2.2: Initialize Terraform
```bash
# Initialize with backend config
terraform init -backend-config=backend.conf

# Expected output: "Terraform has been successfully initialized!"
```

#### Step 2.3: Create Deployment Plan
```bash
# Generate and save plan
terraform plan -var-file=terraform.tfvars -out=vpc-endpoints-dev.tfplan

# Review plan carefully - look for:
# - 20 VPC endpoints to be created
# - 1 security group to be created
# - 0 resources to be destroyed (in new deployment)
# - No unexpected changes to existing resources

# Save plan output for review
terraform show vpc-endpoints-dev.tfplan > vpc-endpoints-dev-plan.txt
```

#### Step 2.4: Review Plan with Team
```bash
# Share plan with team for review
# - Check Slack/Teams for approval
# - Wait for sign-off from Tech Lead
# - Confirm change window with stakeholders
```

#### Step 2.5: Apply Configuration
```bash
# Apply the plan (use saved plan for safety)
terraform apply vpc-endpoints-dev.tfplan

# Monitor output for errors
# Deployment typically takes 5-10 minutes
# You should see "Apply complete! Resources: 21 added, 0 changed, 0 destroyed."
```


#### Step 2.6: Capture Outputs
```bash
# Save all outputs
terraform output -json > dev-vpc-endpoints-outputs.json

# View key outputs
echo "=== VPC Endpoints Created ==="
terraform output vpc_endpoints_all

echo "=== Security Group ==="
terraform output vpc_endpoints_security_group_id

echo "=== Endpoint Counts ==="
terraform output vpc_endpoints_count
```

---

## ✅ Verification & Testing

### Test 1: Verify Endpoints Created

```bash
# Get VPC ID from outputs
VPC_ID=$(terraform output -raw vpc_id)

# List all VPC endpoints
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'VpcEndpoints[*].[VpcEndpointId,ServiceName,State]' \
  --output table

# Expected: 20 endpoints in "available" state
```

### Test 2: DNS Resolution Test

```bash
# Launch a test EC2 instance in private subnet (or use existing)
# SSH into instance and test DNS resolution

# Should resolve to private IPs (10.x.x.x or 172.x.x.x)
nslookup ec2.us-east-1.amazonaws.com
nslookup logs.us-east-1.amazonaws.com
nslookup secretsmanager.us-east-1.amazonaws.com
nslookup s3.us-east-1.amazonaws.com

# All should resolve to VPC private IPs, not public IPs
```

### Test 3: AWS CLI Connectivity Test

```bash
# From EC2 instance in private subnet
# Test AWS CLI commands via endpoints

# Test EC2 endpoint
aws ec2 describe-instances --region us-east-1 --max-results 5

# Test S3 endpoint
aws s3 ls

# Test Secrets Manager endpoint
aws secretsmanager list-secrets --region us-east-1 --max-results 5

# Test CloudWatch Logs endpoint
aws logs describe-log-groups --region us-east-1 --max-results 5

# All commands should work without errors
```

### Test 4: VPC Flow Logs Verification

```bash
# Check VPC Flow Logs for endpoint traffic
# Traffic should show private IP communication

aws ec2 describe-flow-logs \
  --filter "Name=resource-id,Values=$VPC_ID" \
  --query 'FlowLogs[*].[FlowLogId,ResourceId,TrafficType,FlowLogStatus]' \
  --output table

# Query CloudWatch Logs for recent flow logs
aws logs tail /aws/vpc/flowlogs --follow --format short
```

### Test 5: Security Group Validation

```bash
# Get security group ID
SG_ID=$(terraform output -raw vpc_endpoints_security_group_id)

# Verify security group rules
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --query 'SecurityGroups[0].IpPermissions[*].[FromPort,ToPort,IpProtocol,IpRanges[0].CidrIp]' \
  --output table

# Should show HTTPS (443) allowed from VPC CIDR
```

### Test 6: Application Connectivity Test

```bash
# Test from application servers
# Run health checks on critical applications
# Verify no connectivity issues after endpoint deployment

# Example: Test database connections
# Example: Test S3 uploads/downloads
# Example: Test CloudWatch metrics delivery
```

### Test 7: Cost Verification (After 24 hours)

```bash
# Check AWS Cost Explorer for VPC endpoint charges
# Expected: ~$0.01/hour per endpoint (~$7.20/month per endpoint)

# Navigate to AWS Console > Cost Explorer
# Filter by: Service = "EC2 Other" and Usage Type = "VPC Endpoint"
# Verify costs align with expectations (~$136/month for 18 interface endpoints)
```

---

## 🔄 Rollback Procedures

### When to Rollback
- Critical application failures after deployment
- Unexpected costs (>150% of estimate)
- DNS resolution failures affecting multiple services
- Security group misconfigurations causing access issues
- Management approval to rollback

### Rollback Step 1: Assess Impact
```bash
# Document current state
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" > rollback-state.json

# Check application health
# Review error logs
# Assess scope of impact
```

### Rollback Step 2: Disable VPC Endpoints (Quick Fix)
```bash
# If immediate rollback needed, disable endpoints via console
# This is faster than Terraform destroy

cd layers/networking/environments/dev

# Modify terraform.tfvars - set enable_vpc_endpoints = false
sed -i.bak 's/enable_vpc_endpoints = true/enable_vpc_endpoints = false/' terraform.tfvars

# Apply change
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars -auto-approve

# This removes endpoints but keeps infrastructure code
```


### Rollback Step 3: Complete Terraform Destroy (If Needed)
```bash
# Full rollback - destroy all VPC endpoint resources
cd layers/networking/environments/dev

# Target destroy only VPC endpoints module
terraform destroy -target=module.vpc_endpoints -var-file=terraform.tfvars

# Verify endpoints removed
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID"
```

### Rollback Step 4: Restore Previous State
```bash
# If you have a previous state backup
terraform state pull > current-state-backup.json
aws s3 cp s3://your-terraform-state-bucket/pre-deployment-state.tfstate .

# Restore state (use with caution!)
terraform state push pre-deployment-state.tfstate
```

### Rollback Step 5: Verify Services Restored
```bash
# Test application connectivity
# Verify NAT Gateway routing restored
# Check application logs for errors
# Monitor for 30 minutes post-rollback
```

---

## 📝 Post-Deployment Tasks

### Immediate (Within 1 hour)

#### 1. Update Documentation
```bash
# Update deployment tracking document
cat >> DEPLOYMENT_LOG.md << EOF
## Dev Environment Deployment - $(date)
- Status: Success/Failed
- Duration: X minutes
- Endpoints Created: 20
- Issues: None/List issues
- Deployed By: [Your Name]
EOF
```

#### 2. Notify Stakeholders
```
Subject: ✅ VPC Endpoints Deployed - Dev Environment

Team,

VPC Endpoints deployment to Dev environment completed successfully:
- 20 VPC endpoints deployed
- All verification tests passed
- No application issues detected
- Monitoring ongoing for 24 hours

Next deployment: QA environment on [date]

Details: [Link to deployment log]
```

#### 3. Enable Monitoring
```bash
# Create CloudWatch dashboard for endpoints
# Add alarms for endpoint availability
# Set up cost alerts

# Example: Create endpoint availability alarm
aws cloudwatch put-metric-alarm \
  --alarm-name vpc-endpoint-unavailable-dev \
  --alarm-description "Alert when VPC endpoint becomes unavailable" \
  --metric-name EndpointAvailability \
  --namespace AWS/VPC \
  --statistic Average \
  --period 300 \
  --threshold 1 \
  --comparison-operator LessThanThreshold \
  --evaluation-periods 2
```

### Short-term (Within 24 hours)

#### 4. Monitor Performance
```bash
# Check latency improvements
# Review VPC Flow Logs for endpoint usage
# Verify no increase in application errors
# Monitor CloudWatch metrics

# Query VPC Flow Log Insights
# Check for traffic to private IPs (endpoints) vs public IPs
```

#### 5. Cost Analysis
```bash
# Review AWS Cost Explorer
# Compare costs: before vs after endpoints
# Verify NAT Gateway data transfer reduced
# Document actual vs estimated costs
```

#### 6. Documentation Updates
- [ ] Update architecture diagrams with VPC endpoints
- [ ] Update runbooks with new connectivity info
- [ ] Update disaster recovery procedures
- [ ] Update security documentation

### Medium-term (Within 1 week)

#### 7. Team Training
- [ ] Schedule knowledge transfer session
- [ ] Review VPC endpoints troubleshooting
- [ ] Document common issues and resolutions
- [ ] Update on-call playbooks

#### 8. Prepare for Next Environment
- [ ] Schedule QA environment deployment
- [ ] Review lessons learned from Dev
- [ ] Adjust runbook based on Dev experience
- [ ] Prepare change management for QA

---

## 🔍 Troubleshooting Guide

### Issue 1: Endpoint Creation Fails

**Symptoms:**
```
Error: Error creating VPC Endpoint: InvalidParameterValue
```

**Diagnosis:**
```bash
# Check subnet availability
aws ec2 describe-subnets --subnet-ids subnet-xxx

# Verify VPC exists
aws ec2 describe-vpcs --vpc-ids vpc-xxx

# Check service availability in region
aws ec2 describe-vpc-endpoint-services --region us-east-1
```

**Resolution:**
- Verify subnet IDs are correct in terraform.tfvars
- Ensure subnets are in correct AZs
- Check AWS service is available in your region
- Review IAM permissions

### Issue 2: DNS Resolution Not Working

**Symptoms:**
```
nslookup ec2.us-east-1.amazonaws.com
Server: 10.0.0.2
Address: 10.0.0.2#53
Non-authoritative answer:
Name: ec2.us-east-1.amazonaws.com
Address: 52.46.x.x  # Still resolving to public IP!
```

**Diagnosis:**
```bash
# Check if private DNS is enabled
aws ec2 describe-vpc-endpoints \
  --vpc-endpoint-ids vpce-xxx \
  --query 'VpcEndpoints[0].PrivateDnsEnabled'

# Should return: true
```

**Resolution:**
```bash
# Enable private DNS on endpoint
aws ec2 modify-vpc-endpoint \
  --vpc-endpoint-id vpce-xxx \
  --private-dns-enabled

# Verify VPC has DNS support enabled
aws ec2 describe-vpc-attribute \
  --vpc-id vpc-xxx \
  --attribute enableDnsSupport

# Should return: true
```


### Issue 3: Security Group Blocking Traffic

**Symptoms:**
```
aws s3 ls
# Timeout or connection error
```

**Diagnosis:**
```bash
# Check security group rules
SG_ID=$(terraform output -raw vpc_endpoints_security_group_id)
aws ec2 describe-security-groups --group-ids $SG_ID

# Check VPC Flow Logs for rejected traffic
aws logs filter-log-events \
  --log-group-name /aws/vpc/flowlogs \
  --filter-pattern '[version, account, eni, source, destination, srcport, destport="443", protocol="6", packets, bytes, windowstart, windowend, action="REJECT", status]'
```

**Resolution:**
```bash
# Add rule to allow HTTPS from VPC CIDR
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 10.0.0.0/16

# Or update Terraform and re-apply
```

### Issue 4: Terraform State Lock

**Symptoms:**
```
Error: Error acquiring the state lock
Lock Info:
  ID: xxxxx-xxxx-xxxx
  Path: s3://bucket/terraform.tfstate
  Operation: OperationTypeApply
  Who: user@hostname
  Created: 2025-10-12 10:30:00
```

**Diagnosis:**
```bash
# Check DynamoDB for lock
aws dynamodb get-item \
  --table-name terraform-state-lock \
  --key '{"LockID":{"S":"your-state-path"}}'
```

**Resolution:**
```bash
# If lock is stale (confirm no one is actually running terraform!)
terraform force-unlock <lock-id>

# Or manually delete from DynamoDB (use with extreme caution!)
aws dynamodb delete-item \
  --table-name terraform-state-lock \
  --key '{"LockID":{"S":"your-state-path"}}'
```

### Issue 5: High Costs Detected

**Symptoms:**
- Cost Explorer shows VPC endpoint costs >$200/month
- Expected ~$136/month for 18 interface endpoints

**Diagnosis:**
```bash
# Check number of endpoints deployed
aws ec2 describe-vpc-endpoints --query 'VpcEndpoints[*].[VpcEndpointId,ServiceName]' --output table

# Check endpoint configuration (should be multi-AZ)
aws ec2 describe-vpc-endpoints --query 'VpcEndpoints[*].[VpcEndpointId,SubnetIds]' --output table

# Review data transfer costs
# AWS Cost Explorer > EC2 Other > VPC Endpoint Usage
```

**Resolution:**
- Verify correct number of endpoints deployed
- Check for duplicate endpoints
- Review data transfer patterns
- Consider consolidating endpoints if over-provisioned
- Disable unused endpoints

### Issue 6: Application Connection Timeouts

**Symptoms:**
```
Application logs show:
"Connection timeout when calling AWS service"
"Unable to reach S3"
```

**Diagnosis:**
```bash
# From application server, test connectivity
telnet logs.us-east-1.amazonaws.com 443
curl -v https://s3.us-east-1.amazonaws.com

# Check endpoint status
aws ec2 describe-vpc-endpoints \
  --query 'VpcEndpoints[?State!=`available`].[VpcEndpointId,ServiceName,State]' \
  --output table

# Review VPC Flow Logs for traffic to endpoints
```

**Resolution:**
1. Verify endpoint is in "available" state
2. Check security group allows traffic from application subnet
3. Verify route tables have correct routes
4. Test DNS resolution from application server
5. Check if AWS service is experiencing outage (AWS Status page)

### Issue 7: Terraform Plan Shows Unexpected Changes

**Symptoms:**
```
Terraform will perform the following actions:
  # module.vpc_endpoints.aws_vpc_endpoint.interface["ec2"] will be updated in-place
  ~ resource "aws_vpc_endpoint" "interface" {
      ~ private_dns_enabled = false -> true
    }
```

**Diagnosis:**
```bash
# Check current state
terraform show

# Compare with configuration
cat main.tf | grep -A5 "vpc_endpoint"

# Review state file
terraform state show 'module.vpc_endpoints.aws_vpc_endpoint.interface["ec2"]'
```

**Resolution:**
- Review if changes are expected
- If drift detected, consider refreshing state: `terraform refresh`
- If intentional config changes, proceed with apply
- If unintentional, investigate who made manual changes

---

## 📞 Emergency Contacts

### Deployment Team

| Role | Name | Contact | Availability |
|------|------|---------|-------------|
| **Tech Lead** | [Name] | [Email/Phone] | 24/7 during deployment |
| **Platform Engineer** | [Name] | [Email/Phone] | Business hours + on-call |
| **Network Engineer** | [Name] | [Email/Phone] | Business hours + on-call |
| **DevOps Lead** | [Name] | [Email/Phone] | 24/7 during deployment |

### Escalation Path

1. **Level 1**: Deployment team resolves (0-30 minutes)
2. **Level 2**: Tech Lead + Senior Engineer (30-60 minutes)
3. **Level 3**: Director of Engineering (>60 minutes or critical impact)
4. **Level 4**: CTO (major production outage)

### Communication Channels

- **Primary**: Slack #vpc-endpoints-deployment
- **Secondary**: Teams - Platform Engineering
- **Emergency**: PagerDuty - Platform Team
- **Status Updates**: Slack #engineering-status

### AWS Support

- **AWS Account**: [Account ID]
- **Support Plan**: Business/Enterprise
- **TAM Contact**: [Name/Email] (if Enterprise)
- **Support Phone**: 1-800-xxx-xxxx
- **Support Case Priority**: High (for production issues)

---

## 📊 Success Criteria

### Deployment Success Checklist

- [ ] All 20 VPC endpoints in "available" state
- [ ] DNS resolution works from private subnets
- [ ] AWS CLI commands work via endpoints
- [ ] Application connectivity verified
- [ ] No increase in application errors
- [ ] VPC Flow Logs show endpoint traffic
- [ ] Security groups properly configured
- [ ] Costs align with estimates
- [ ] Documentation updated
- [ ] Team notified of completion


### Key Performance Indicators (KPIs)

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| **Deployment Time** | < 30 minutes | Terraform apply duration |
| **Endpoint Availability** | 100% | AWS Console / CLI check |
| **DNS Resolution Success** | 100% | nslookup tests from private subnet |
| **Application Error Rate** | No increase | Application logs analysis |
| **Latency Improvement** | 20-30% reduction | CloudWatch metrics comparison |
| **Cost Variance** | Within 10% of estimate | AWS Cost Explorer |
| **Rollback Time (if needed)** | < 15 minutes | Terraform destroy duration |

---

## 📅 Deployment Timeline

### Pre-Production Environments

#### Week 1: Dev Environment
- **Monday**: Final code review and team briefing
- **Tuesday**: Dev deployment (2-4 hour window)
- **Wednesday-Friday**: Monitoring and testing
- **Weekend**: Review results, adjust if needed

#### Week 2: QA Environment
- **Monday**: Incorporate Dev lessons learned
- **Tuesday**: QA deployment
- **Wednesday-Thursday**: Testing and validation
- **Friday**: QA sign-off

#### Week 3: UAT Environment
- **Monday-Tuesday**: UAT deployment
- **Wednesday-Friday**: User acceptance testing

### Production Environment

#### Week 4: Production Deployment
- **Monday-Wednesday**: Final preparation and rehearsal
- **Thursday**: Production deployment (scheduled maintenance window)
  - **Window**: 2:00 AM - 6:00 AM EST (low traffic period)
  - **Duration**: 2 hours deployment + 2 hours validation
- **Friday**: Post-deployment review and documentation

---

## 📈 Monitoring & Metrics

### CloudWatch Dashboards to Create

```bash
# Create VPC Endpoints dashboard
aws cloudwatch put-dashboard --dashboard-name vpc-endpoints-monitoring \
--dashboard-body '{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/VPC", "EndpointConnections", {"stat": "Sum"}],
          [".", "EndpointPacketsIn", {"stat": "Sum"}],
          [".", "EndpointPacketsOut", {"stat": "Sum"}],
          [".", "EndpointBytesIn", {"stat": "Sum"}],
          [".", "EndpointBytesOut", {"stat": "Sum"}]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-1",
        "title": "VPC Endpoint Metrics"
      }
    }
  ]
}'
```

### Key Metrics to Monitor

1. **Endpoint Availability**
   - Metric: VPC endpoint state
   - Threshold: Must be "available"
   - Action: Alert if not available for >5 minutes

2. **DNS Resolution Time**
   - Metric: Custom CloudWatch metric
   - Threshold: < 100ms
   - Action: Alert if >500ms

3. **Application Error Rate**
   - Metric: Application-specific
   - Threshold: No increase from baseline
   - Action: Investigate any increase >5%

4. **Latency to AWS Services**
   - Metric: Application API call duration
   - Expected: 20-30% reduction
   - Action: Verify if no improvement seen

5. **Cost Per Day**
   - Metric: AWS Cost Explorer API
   - Threshold: ~$4.50/day (for $136/month)
   - Action: Alert if >$6/day

---

## 🎓 Lessons Learned Template

```markdown
## VPC Endpoints Deployment - Lessons Learned

### Date: [Deployment Date]
### Environment: [Dev/QA/UAT/Prod]
### Deployment Duration: [X hours]

### What Went Well ✅
- 
- 
- 

### What Didn't Go Well ❌
- 
- 
- 

### Unexpected Issues 🔍
- 
- 
- 

### Actions for Next Deployment 📋
- 
- 
- 

### Process Improvements 🔧
- 
- 
- 

### Documentation Updates Needed 📝
- 
- 
- 
```

---

## 📚 Additional Resources

### Documentation Links
- [AWS VPC Endpoints Documentation](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [Terraform AWS VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
- [AWS PrivateLink Pricing](https://aws.amazon.com/privatelink/pricing/)
- [VPC Endpoint Service Names](https://docs.aws.amazon.com/vpc/latest/privatelink/aws-services-privatelink-support.html)

### Internal Resources
- [VPC_ENDPOINTS_COMPLETION.md](./VPC_ENDPOINTS_COMPLETION.md)
- [modules/vpc-endpoints/README.md](./modules/vpc-endpoints/README.md)
- [layers/networking/README.md](./layers/networking/README.md)
- Architecture Diagrams: [Confluence/Wiki Link]
- Team Runbooks: [Confluence/Wiki Link]

### Training Materials
- AWS re:Invent Sessions on VPC Endpoints
- Internal Wiki: "VPC Endpoints Best Practices"
- Brown Bag Session Slides: [Link]

---

## ✅ Sign-Off

### Deployment Authorization

| Role | Name | Signature | Date |
|------|------|-----------|------|
| **Deployment Lead** | | | |
| **Tech Lead** | | | |
| **Platform Engineer** | | | |
| **Engineering Manager** | | | |

### Post-Deployment Sign-Off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| **Deployment Lead** | | | |
| **QA Lead** | | | |
| **Security Review** | | | |
| **Engineering Manager** | | | |

---

## 📋 Appendix

### Appendix A: Terraform Commands Quick Reference

```bash
# Initialize
terraform init -backend-config=backend.conf

# Format
terraform fmt -recursive

# Validate
terraform validate

# Plan
terraform plan -var-file=terraform.tfvars -out=plan.tfplan

# Apply
terraform apply plan.tfplan

# Destroy (rollback)
terraform destroy -target=module.vpc_endpoints

# Show outputs
terraform output -json

# Refresh state
terraform refresh

# Import existing resource
terraform import aws_vpc_endpoint.example vpce-xxxxx
```

### Appendix B: AWS CLI Commands Quick Reference

```bash
# List VPC endpoints
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=vpc-xxx"

# Get endpoint details
aws ec2 describe-vpc-endpoints --vpc-endpoint-ids vpce-xxx

# List available services
aws ec2 describe-vpc-endpoint-services --region us-east-1

# Modify endpoint
aws ec2 modify-vpc-endpoint --vpc-endpoint-id vpce-xxx --private-dns-enabled

# Delete endpoint (emergency only!)
aws ec2 delete-vpc-endpoints --vpc-endpoint-ids vpce-xxx
```

### Appendix C: Common DNS Names

| Service | DNS Name |
|---------|----------|
| EC2 | ec2.region.amazonaws.com |
| S3 | s3.region.amazonaws.com |
| CloudWatch Logs | logs.region.amazonaws.com |
| Secrets Manager | secretsmanager.region.amazonaws.com |
| Systems Manager | ssm.region.amazonaws.com |
| KMS | kms.region.amazonaws.com |
| ECR API | api.ecr.region.amazonaws.com |
| ECR Docker | dkr.ecr.region.amazonaws.com |
| Lambda | lambda.region.amazonaws.com |

---

**Document Control:**
- **Version**: 1.0
- **Last Updated**: October 12, 2025
- **Next Review Date**: November 12, 2025
- **Owner**: Platform Engineering Team
- **Classification**: Internal Use Only

---

**End of Deployment Runbook**
