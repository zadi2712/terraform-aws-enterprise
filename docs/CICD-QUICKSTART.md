# CI/CD Quick Start Guide

Get started with GitHub Actions infrastructure deployment in 5 minutes.

## ⚡ Prerequisites

- [ ] GitHub repository access
- [ ] AWS credentials (Access Key ID and Secret Access Key)
- [ ] Terraform backend configured (S3 + DynamoDB)

## 🚀 Setup (5 Minutes)

### Step 1: Configure GitHub Secrets (2 min)

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add these secrets:

```
Name: AWS_ACCESS_KEY_ID
Value: AKIA................

Name: AWS_SECRET_ACCESS_KEY
Value: wJalrX...............

Name: AWS_REGION
Value: us-east-1
```

### Step 2: Configure Environments (2 min)

1. Go to **Settings** → **Environments**
2. Create four environments:
   - `dev` (no restrictions)
   - `qa` (no restrictions)
   - `uat` (optional: add 1 reviewer)
   - `prod` (required: add 2 reviewers + wait timer)

### Step 3: Test the Pipeline (1 min)

1. Go to **Actions** tab
2. Select **Deploy Networking Layer**
3. Click **Run workflow**
4. Select:
   - Environment: `dev`
   - Action: `plan`
5. Click **Run workflow**
6. ✅ If successful, you're ready to go!

## 📖 Basic Usage

### Deploy a Single Layer

```
Actions → Deploy [Layer] Layer → Run workflow
  Environment: dev
  Action: plan (review first)
  
Then:
  Action: apply (to deploy)
```

### Deploy All Layers

```
Actions → Deploy All Layers → Run workflow
  Environment: dev
  Action: plan (review all layers)
  
Then:
  Action: apply (deploy all)
```

### Deploy via Pull Request

```bash
# 1. Create feature branch
git checkout -b feature/update-vpc

# 2. Make changes
vim layers/networking/main.tf

# 3. Commit and push
git add .
git commit -m "feat: update VPC CIDR"
git push origin feature/update-vpc

# 4. Create PR in GitHub
# → Plan runs automatically
# → Review plan in PR comments

# 5. Merge PR
# → Auto-deploys to dev
```

## 🎯 Common Tasks

### Task: Deploy Networking to Dev

```
1. Actions → Deploy Networking Layer
2. Run workflow (env=dev, action=apply)
3. Wait for completion
4. ✅ Done!
```

### Task: Update Compute in Production

```
1. Create PR with changes
2. Review plan in PR comments
3. Merge to main (deploys to dev)
4. Actions → Deploy Compute Layer
5. Run workflow (env=prod, action=plan)
6. Review plan
7. Run workflow (env=prod, action=apply)
8. Get approval (2 reviewers required)
9. ✅ Deployment starts
```

### Task: Rollback a Change

```
# Option A: Git revert
git revert <commit-hash>
git push origin main
# → Auto-deploys to dev

# Option B: Manual
Actions → Deploy [Layer] → Run workflow
  Environment: [env]
  Action: destroy
Then redeploy previous version
```

## 🔄 Deployment Flow

```
┌─────────────┐
│ Local Dev   │
└──────┬──────┘
       │ git push
       ▼
┌─────────────┐
│ PR Created  │──→ Automatic plan on dev
└──────┬──────┘
       │ Review & Merge
       ▼
┌─────────────┐
│ Main Branch │──→ Auto-deploy to dev
└──────┬──────┘
       │ Manual trigger
       ▼
┌─────────────┐
│ QA/UAT      │──→ Manual approval
└──────┬──────┘
       │ Manual trigger
       ▼
┌─────────────┐
│ Production  │──→ 2 reviewers + wait timer
└─────────────┘
```

## 💡 Pro Tips

### Tip 1: Always Plan First

```
✅ DO: Run 'plan' → Review → Run 'apply'
❌ DON'T: Run 'apply' directly
```

### Tip 2: Use Path Filters

Workflows only trigger when relevant files change:
- Change networking files → networking workflow runs
- Change compute files → compute workflow runs

### Tip 3: Monitor Deployments

Check GitHub Actions tab regularly:
- Green ✅ = Success
- Red ❌ = Failed (check logs)
- Yellow 🟡 = In progress

### Tip 4: Leverage Artifacts

Download Terraform plans from workflow runs:
```
Actions → Select run → Artifacts → Download tfplan
```

### Tip 5: Use Concurrency Control

Workflows prevent simultaneous deployments:
- Same layer + same environment = serialized
- Different layers = can run in parallel

## 🔧 Troubleshooting

### Problem: Workflow doesn't run

**Check**:
- File paths match trigger paths
- Branch matches trigger branch
- Changes are committed and pushed

### Problem: AWS credentials fail

**Fix**:
1. Verify secrets are set correctly
2. Check IAM permissions
3. Try re-creating secrets

### Problem: State lock error

**Fix**:
1. Wait a few minutes (lock may auto-release)
2. Check for hung workflows and cancel
3. If persistent, force unlock (with caution)

### Problem: Plan shows unexpected changes

**Fix**:
1. Check for manual AWS Console changes
2. Review Terraform state
3. Consider running refresh

## 📚 Next Steps

- Read full documentation: [`/docs/CICD.md`](../docs/CICD.md)
- Review workflow files: [`/.github/workflows/README.md`](../.github/workflows/README.md)
- Explore deployment runbook: [`/docs/DEPLOYMENT_RUNBOOK.md`](../docs/DEPLOYMENT_RUNBOOK.md)

## 🎓 Learning Path

1. ✅ Complete this quick start
2. ✅ Deploy networking layer to dev
3. ✅ Create a test PR and review plan
4. ✅ Deploy all layers to dev
5. ✅ Promote to qa environment
6. ✅ Read full CI/CD documentation
7. ✅ Configure prod environment protection
8. ✅ Practice production deployment

## 📞 Get Help

- **Documentation**: Check `/docs/CICD.md`
- **Logs**: Review GitHub Actions logs
- **Team**: Ask on Slack #infrastructure
- **Issues**: Create GitHub issue with details

## ✅ Checklist

Before first deployment:

- [ ] GitHub secrets configured
- [ ] Environments created
- [ ] Backend S3 buckets exist
- [ ] DynamoDB tables exist for locking
- [ ] IAM permissions configured
- [ ] Test workflow run successful
- [ ] Team members have access
- [ ] Documentation reviewed

## 🎉 You're Ready!

You're now ready to deploy infrastructure using GitHub Actions. Start with dev environment and work your way up to production.

**Remember**: 
- 🔒 Security first
- 📋 Always plan before apply
- 👥 Get reviews for prod
- 📊 Monitor deployments

---

**Quick Reference Card**: Keep this page bookmarked for easy access!

| Action | Command |
|--------|---------|
| Deploy layer | Actions → Deploy [Layer] → Run workflow |
| Deploy all | Actions → Deploy All Layers |
| View logs | Actions → Select run → View logs |
| Rollback | Revert commit → Push to main |
| Get help | Check `/docs/CICD.md` |

---

**Last Updated**: October 2025  
**Maintained By**: Platform Engineering Team
