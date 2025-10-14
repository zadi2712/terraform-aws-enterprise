# Branch-Based Deployment Quick Reference

## 🎯 Overview

The branch-based deployment workflow automatically deploys your infrastructure to different environments based on which Git branch you push to. This provides a GitOps-style deployment flow.

## 🌳 Branch → Environment Mapping

| Branch | Deploys To | Use Case |
|--------|-----------|----------|
| `dev` | DEV | Development and testing |
| `staging` | QA | Quality assurance and pre-production testing |
| `main` | PROD + UAT | Production and User Acceptance Testing |

## 📋 What Gets Deployed

When you push to a branch, **all 7 infrastructure layers** are deployed automatically in the correct dependency order:

1. **Networking** (VPC, Subnets, Endpoints)
2. **Security** (IAM, KMS, Security Groups)
3. **Storage** (S3, EFS)
4. **Database** (RDS, DynamoDB)
5. **Compute** (EKS, EC2, ASG)
6. **DNS** (Route53)
7. **Monitoring** (CloudWatch)

## 🚀 Common Workflows

### Deploy to Development
```bash
git checkout dev
# Make your changes
git add .
git commit -m "feat: add new feature"
git push origin dev
# ✅ Automatically deploys to DEV environment
```

### Promote DEV → QA
```bash
git checkout staging
git merge dev
git push origin staging
# ✅ Automatically deploys to QA environment
```

### Promote QA → Production
```bash
git checkout main
git merge staging
git push origin main
# ✅ Automatically deploys to BOTH prod AND uat environments
```

## 🔄 Complete Promotion Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Feature Development                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
              ┌────────────────┐
              │  Push to dev   │──────► Auto-Deploy to DEV
              │     branch     │
              └────────┬───────┘
                       │
                       │ Test in DEV
                       │
                       ▼
              ┌────────────────┐
              │ Merge dev into │
              │    staging     │──────► Auto-Deploy to QA
              └────────┬───────┘
                       │
                       │ Test in QA
                       │
                       ▼
              ┌────────────────┐
              │ Merge staging  │
              │   into main    │──────► Auto-Deploy to PROD + UAT
              └────────────────┘
```

## ⚡ Quick Commands

### Start New Feature
```bash
# Start from dev branch
git checkout dev
git pull origin dev
git checkout -b feature/my-new-feature

# Make changes...
git add .
git commit -m "feat: description"
git push origin feature/my-new-feature

# Create PR to dev branch
# After approval, merge to dev → Auto-deploys to DEV
```

### Emergency Hotfix
```bash
# Start from main
git checkout main
git pull origin main
git checkout -b hotfix/critical-issue

# Fix the issue...
git add .
git commit -m "fix: critical issue"
git push origin hotfix/critical-issue

# Create PR to main branch
# After approval, merge to main → Auto-deploys to PROD + UAT
```

## 🛡️ Safety Features

### Concurrency Control
- Only one deployment per branch at a time
- Prevents race conditions and state conflicts
- Safe to push multiple commits; they queue automatically

### Path Filtering
The workflow **ignores** changes to:
- `**.md` - Markdown documentation files
- `docs/**` - Documentation directory
- `.gitignore` - Git configuration
- `LICENSE` - License file

This means documentation updates won't trigger deployments.

### Required Checks
Each layer:
1. ✅ Format validation
2. ✅ Terraform init
3. ✅ Terraform validate
4. ✅ Terraform plan
5. ✅ Terraform apply

## 📊 Monitoring Deployments

### View in GitHub Actions
1. Go to your repository
2. Click **Actions** tab
3. Look for "Branch-Based Auto Deployment"
4. Click on a workflow run to see details

### Deployment Summary
Each run generates a comprehensive summary showing:
- Which branch triggered the deployment
- Which environment(s) were deployed to
- Status of each layer (success/failure)
- Timestamp and commit information

## 🚫 When NOT to Use Branch-Based Deployment

Use manual workflows instead when you need to:
- ❌ Deploy only a specific layer (use layer-specific workflows)
- ❌ Run `plan` without `apply` (use manual workflow with plan action)
- ❌ Run `destroy` operations (use manual workflow with destroy action)
- ❌ Deploy to a specific environment regardless of branch

## 🔍 Troubleshooting

### Deployment didn't trigger
**Check**:
- Did you push to `main`, `dev`, or `staging` branch?
- Did you only change documentation files? (These are ignored)
- Check the Actions tab for any failures

### Deployment failed
**Steps**:
1. Check the workflow run logs in GitHub Actions
2. Look for the specific layer that failed
3. Check Terraform error messages
4. Verify AWS credentials and permissions
5. Check for state lock issues

### Need to skip automatic deployment
**Options**:
1. Add `[skip ci]` to your commit message
2. Push to a different branch (not main/dev/staging)
3. Disable the workflow temporarily in `.github/workflows/`

## 🔐 Required Setup

### GitHub Secrets
Ensure these secrets are configured in your repository settings:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION` (optional, defaults to us-east-1)

### Branch Protection
Recommended branch protection rules:
- **main**: Require pull request reviews (2), require status checks
- **staging**: Require pull request reviews (1), require status checks
- **dev**: Require status checks (optional reviews)

## 📝 Best Practices

1. **Always test in DEV first**
   - Never push directly to main
   - Use the promotion flow: dev → staging → main

2. **Use descriptive commit messages**
   ```bash
   feat: add new monitoring dashboard
   fix: resolve database connection issue
   docs: update deployment instructions
   ```

3. **Review changes before merging**
   - Create PRs for all changes
   - Review Terraform plans
   - Get team approval

4. **Monitor deployments**
   - Watch the GitHub Actions run
   - Check deployment summary
   - Verify in AWS console

5. **Keep branches in sync**
   - Regularly merge main → staging → dev
   - Avoid long-lived feature branches
   - Resolve conflicts early

## 🆘 Emergency Rollback

If you need to roll back a deployment:

```bash
# Option 1: Revert the commit
git checkout main
git revert <commit-hash>
git push origin main  # Deploys the reverted state

# Option 2: Reset to previous state
git checkout main
git reset --hard <previous-commit>
git push origin main --force  # Use with caution!

# Option 3: Manual rollback using GitHub UI
# Use "Revert" button on the merge commit in GitHub
```

## 📞 Getting Help

- **Documentation**: Check `/docs/CICD.md` for comprehensive guide
- **Workflow Issues**: Review logs in GitHub Actions tab
- **Infrastructure Issues**: Check AWS Console and CloudWatch logs
- **Team Support**: Contact DevOps team on Slack #infrastructure

---

**Quick Tip**: Start small! Test your changes in DEV, verify they work, then promote through staging to production. This workflow is designed to make this process smooth and automatic.
