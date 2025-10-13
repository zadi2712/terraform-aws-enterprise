# CI/CD Practical Examples

Real-world scenarios and step-by-step solutions using the GitHub Actions pipeline.

## 📋 Table of Contents

1. [Daily Development Workflow](#daily-development-workflow)
2. [Emergency Hotfix](#emergency-hotfix)
3. [Multi-Environment Deployment](#multi-environment-deployment)
4. [Rollback Procedure](#rollback-procedure)
5. [Layer-by-Layer Infrastructure Buildout](#layer-by-layer-infrastructure-buildout)
6. [Production Deployment](#production-deployment)
7. [Troubleshooting Common Issues](#troubleshooting-common-issues)

---

## 1. Daily Development Workflow

**Scenario**: You need to update the VPC CIDR block in the networking layer.

### Step-by-Step

```bash
# 1. Create feature branch
git checkout -b feature/update-vpc-cidr

# 2. Make changes
cd layers/networking/environments/dev
vim terraform.tfvars

# Edit:
vpc_cidr = "10.1.0.0/16"  # Changed from 10.0.0.0/16

# 3. Commit changes
git add .
git commit -m "feat: update VPC CIDR to 10.1.0.0/16 for dev"

# 4. Push branch
git push origin feature/update-vpc-cidr
```

### GitHub Actions Workflow

```
1. Go to GitHub → Create Pull Request
2. GitHub Actions automatically runs:
   ✓ Checkout code
   ✓ Run terraform plan on dev
   ✓ Post plan as PR comment
   
3. Review plan output in PR comments:
   Plan: 1 to change, 0 to add, 0 to destroy
   
4. Get approval from team member

5. Merge PR → Triggers automatic deployment to dev
   ✓ terraform apply runs automatically
   ✓ VPC CIDR updated in dev environment
```

**Expected Timeline**: 5-10 minutes

---

## 2. Emergency Hotfix

**Scenario**: Production networking layer has a misconfiguration causing service disruption. Need immediate fix.

### Step-by-Step

```bash
# 1. Create hotfix branch directly from main
git checkout main
git pull
git checkout -b hotfix/security-group-rules

# 2. Make critical fix
cd layers/networking/environments/prod
vim terraform.tfvars

# Fix misconfigured security group
ingress_rules = [
  {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]  # Fixed: was 0.0.0.0/0
  }
]

# 3. Commit with clear message
git add .
git commit -m "hotfix: restrict security group to internal IPs only"
git push origin hotfix/security-group-rules

# 4. Create PR with "HOTFIX" label
# Request expedited review
```

### Deployment Process

```
1. Create PR with HOTFIX label
2. Get emergency approval (can skip normal wait time)
3. Merge to main
4. Manual trigger for production:
   
   GitHub Actions → Deploy Networking Layer → Run workflow
   - Environment: prod
   - Action: plan (verify fix)
   
5. Review plan carefully
   
6. Apply:
   - Environment: prod
   - Action: apply
   
7. Get 2 approvals (expedited)
8. Monitor deployment closely
```

**Expected Timeline**: 15-30 minutes (expedited)

---

## 3. Multi-Environment Deployment

**Scenario**: New EKS cluster configuration needs to be deployed across all environments.

### Step-by-Step

```bash
# 1. Create feature branch
git checkout -b feature/eks-upgrade

# 2. Update all environment files
for env in dev qa uat prod; do
  vim layers/compute/environments/$env/terraform.tfvars
done

# Update EKS version:
eks_version = "1.28"

# 3. Commit all changes
git add .
git commit -m "feat: upgrade EKS to version 1.28 across all environments"
git push origin feature/eks-upgrade
```

### Progressive Deployment

```
Phase 1: Development
──────────────────
1. Create PR → Auto-plan on dev
2. Review plan
3. Merge PR → Auto-deploy to dev
4. Validate in dev environment
5. Run integration tests
   
Phase 2: QA
──────────────────
GitHub Actions → Deploy Compute Layer → Run workflow
- Environment: qa
- Action: plan
Review plan → Apply:
- Environment: qa
- Action: apply
Validate in QA

Phase 3: UAT
──────────────────
GitHub Actions → Deploy Compute Layer → Run workflow
- Environment: uat
- Action: plan
Get 1 approval → Apply:
- Environment: uat
- Action: apply
Validate in UAT

Phase 4: Production
──────────────────
GitHub Actions → Deploy Compute Layer → Run workflow
- Environment: prod
- Action: plan
Get 2 approvals
Wait 10 minutes (cooling period) → Apply:
- Environment: prod
- Action: apply
Monitor deployment
Validate in production
```

**Expected Timeline**: 2-4 hours (with testing)

---

## 4. Rollback Procedure

**Scenario**: A deployment to production caused issues. Need to rollback immediately.

### Option A: Git Revert (Recommended)

```bash
# 1. Identify problematic commit
git log --oneline

# Example output:
# abc123 feat: update compute configuration
# def456 fix: security group rules
# ghi789 docs: update README

# 2. Revert the problematic commit
git revert abc123

# 3. Push revert
git push origin main

# 4. This triggers automatic deployment to dev
# 5. Then manually deploy to prod (expedited approval)
```

### Option B: Manual Rollback

```
1. Find last known good commit
   git log --oneline

2. Checkout that version of the file
   git checkout def456 -- layers/compute/environments/prod/terraform.tfvars

3. Commit rollback
   git add .
   git commit -m "rollback: revert compute to version def456"
   git push origin main

4. Deploy to production
   GitHub Actions → Deploy Compute → Run workflow
   - Environment: prod
   - Action: apply
   - Get expedited approval
```

### Option C: Destroy and Redeploy

```
⚠️ Use only as last resort

1. Backup current state
   aws s3 cp s3://bucket/compute/prod/terraform.tfstate \
             s3://bucket/backups/compute-prod-$(date +%Y%m%d-%H%M%S).tfstate

2. Destroy problematic resources
   GitHub Actions → Deploy Compute → Run workflow
   - Environment: prod
   - Action: destroy
   - Confirm destruction

3. Checkout last known good configuration
   git checkout def456 -- layers/compute/

4. Redeploy
   GitHub Actions → Deploy Compute → Run workflow
   - Environment: prod
   - Action: apply
```

**Expected Timeline**: 15-45 minutes depending on method

---

## 5. Layer-by-Layer Infrastructure Buildout

**Scenario**: Setting up complete infrastructure for a new environment from scratch.

### Complete Buildout Process

```bash
# 1. Create environment configuration files
mkdir -p layers/{networking,security,storage,database,compute,dns,monitoring}/environments/staging

# 2. Copy and modify configuration from existing environment
for layer in networking security storage database compute dns monitoring; do
  cp layers/$layer/environments/prod/terraform.tfvars \
     layers/$layer/environments/staging/terraform.tfvars
  cp layers/$layer/environments/prod/backend.tfvars \
     layers/$layer/environments/staging/backend.tfvars
done

# 3. Update all staging configurations
# Edit environment-specific values (VPC CIDR, instance sizes, etc.)

# 4. Commit new environment
git checkout -b feature/add-staging-environment
git add .
git commit -m "feat: add staging environment configuration"
git push origin feature/add-staging-environment
```

### Sequential Deployment

```
Use the "Deploy All Layers" workflow for initial buildout:

1. GitHub Actions → Deploy All Layers → Run workflow
   - Environment: staging
   - Action: plan
   - Skip layers: (leave empty)

2. Review all layer plans carefully
   - Verify networking resources
   - Check security configurations
   - Validate database settings
   - Review compute capacity

3. Apply all layers
   - Environment: staging
   - Action: apply

4. Monitor sequential deployment:
   1️⃣ Networking (5-10 min)
      └─ VPC, Subnets, VPC Endpoints
   
   2️⃣ Security (3-5 min)
      └─ IAM Roles, KMS Keys, Security Groups
   
   3️⃣ Storage (2-4 min)
      └─ S3 Buckets, EFS
   
   4️⃣ Database (10-15 min)
      └─ RDS Instances, DynamoDB Tables
   
   5️⃣ Compute (15-20 min)
      └─ EKS Cluster, Node Groups
   
   6️⃣ DNS (2-3 min)
      └─ Route53 Zones, Records
   
   7️⃣ Monitoring (3-5 min)
      └─ CloudWatch Dashboards, Alarms

5. Post-deployment validation
   - Check AWS Console for all resources
   - Verify connectivity
   - Run smoke tests
   - Update documentation
```

**Expected Timeline**: 45-60 minutes

---

## 6. Production Deployment

**Scenario**: Deploying a major infrastructure change to production with full safety checks.

### Pre-Deployment Checklist

```
□ Changes tested in dev
□ Changes tested in qa
□ Changes tested in uat
□ Backup of current state exists
□ Rollback plan documented
□ Change window scheduled
□ Stakeholders notified
□ On-call engineer available
□ Monitoring alerts configured
```

### Deployment Process

```bash
# 1. Final validation in staging/UAT
git checkout main
git pull

# 2. Verify no unexpected changes
cd layers/compute/environments/prod
terraform plan -var-file=terraform.tfvars

# 3. Schedule deployment window
# Example: Saturday 2 AM - 4 AM EST
```

### GitHub Actions Execution

```
T-60min: Pre-deployment
──────────────────────
1. Team standup call
2. Review deployment plan
3. Confirm rollback procedure
4. Put monitoring on high alert

T-15min: Plan Generation
──────────────────────
GitHub Actions → Deploy Compute → Run workflow
- Environment: prod
- Action: plan

Review plan with team:
- Verify expected changes only
- Check for any surprises
- Confirm no data loss

T-0: Execute Deployment
──────────────────────
GitHub Actions → Deploy Compute → Run workflow
- Environment: prod
- Action: apply
- Get 2 approvals
- Wait 10 minutes

T+5min: Monitoring
──────────────────────
- Watch GitHub Actions logs
- Monitor CloudWatch
- Check application health endpoints
- Verify no errors

T+15min: Validation
──────────────────────
- Run smoke tests
- Check critical paths
- Verify user access
- Monitor error rates

T+30min: Sign-off
──────────────────────
- Team confirms success
- Update runbook
- Notify stakeholders
- Close change ticket
```

**Expected Timeline**: 2-3 hours (including buffer)

---

## 7. Troubleshooting Common Issues

### Issue: Terraform State Lock

```bash
# Symptom
Error: Error acquiring the state lock

# Investigation
1. Check GitHub Actions for running workflows
   Actions → View active runs

2. Check DynamoDB lock table
   aws dynamodb scan --table-name terraform-state-lock-prod

# Solution A: Wait for lock release (if workflow is running)
# Solution B: Force unlock (if workflow is stuck)
terraform force-unlock <lock-id>

# Solution C: Via GitHub Actions
# Cancel stuck workflow
Actions → Select workflow → Cancel workflow run
```

### Issue: AWS Credentials Expired

```bash
# Symptom
Error: error configuring Terraform AWS Provider

# Solution
1. Rotate credentials
   AWS Console → IAM → Users → Security Credentials → Create Access Key

2. Update GitHub Secrets
   Settings → Secrets → Update AWS_ACCESS_KEY_ID
   Settings → Secrets → Update AWS_SECRET_ACCESS_KEY

3. Re-run workflow
```

### Issue: Resource Already Exists

```bash
# Symptom
Error: VPC already exists

# Solution A: Import existing resource
terraform import module.vpc.aws_vpc.main vpc-12345

# Solution B: Remove resource manually
aws ec2 delete-vpc --vpc-id vpc-12345

# Solution C: Use different resource identifier
# Update terraform.tfvars with unique name
```

### Issue: Plan Shows No Changes But Resources Missing

```bash
# Investigation
1. Check terraform state
   terraform state list

2. Check AWS Console
   aws ec2 describe-vpcs

# Solution: Refresh state
terraform refresh -var-file=environments/prod/terraform.tfvars

# Or via GitHub Actions
Actions → Deploy [Layer] → Run workflow
- Action: plan (this includes refresh)
```

---

## 📊 Success Metrics

Track these metrics for your CI/CD pipeline:

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Deployment Success Rate | >95% | GitHub Actions success/total runs |
| Mean Time to Deploy | <30 min | Average workflow duration |
| Mean Time to Rollback | <15 min | Time from issue detection to rollback |
| Plan Accuracy | 100% | Plans matching actual changes |
| Failed Deployments | <5% | Failed workflows / total workflows |

---

## 🎓 Learning Exercises

Practice these scenarios in dev environment:

1. **Exercise 1**: Deploy networking layer
2. **Exercise 2**: Update configuration and create PR
3. **Exercise 3**: Deploy all layers sequentially
4. **Exercise 4**: Perform a rollback
5. **Exercise 5**: Add a new environment
6. **Exercise 6**: Handle a failed deployment
7. **Exercise 7**: Destroy and rebuild a layer

---

## 📚 Additional Resources

- [CI/CD Full Documentation](CICD.md)
- [Quick Start Guide](CICD-QUICKSTART.md)
- [Architecture Diagrams](CICD-ARCHITECTURE.md)
- [Deployment Runbook](DEPLOYMENT_RUNBOOK.md)

---

**Last Updated**: October 2025  
**Maintained By**: Platform Engineering Team
