# GitHub Actions CI/CD - Quick Reference Cheat Sheet

## 🚀 Common Commands

| Task | Steps |
|------|-------|
| **Deploy to Dev** | Actions → Deploy [Layer] → env=dev, action=apply |
| **Deploy to Prod** | Actions → Deploy [Layer] → env=prod, action=plan → Review → action=apply |
| **Deploy All Layers** | Actions → Deploy All Layers → select env & action |
| **Rollback** | `git revert <hash>` → `git push` |
| **View Logs** | Actions → Select Run → View logs |

## 📁 Workflow Files

| File | Purpose |
|------|---------|
| `reusable-terraform.yml` | Core workflow logic |
| `deploy-networking.yml` | VPC, Subnets, Endpoints |
| `deploy-security.yml` | IAM, KMS, Security Groups |
| `deploy-compute.yml` | EKS, EC2, ASG |
| `deploy-database.yml` | RDS, DynamoDB |
| `deploy-storage.yml` | S3, EFS |
| `deploy-dns.yml` | Route53 |
| `deploy-monitoring.yml` | CloudWatch |
| `deploy-all-layers.yml` | All layers in sequence |

## 🔄 Deployment Order

```
1. Networking → 2. Security → 3. Storage → 4. Database → 5. Compute → 6. DNS → 7. Monitoring
```

## 🎯 Triggers

| Type | When | Action |
|------|------|--------|
| **PR** | PR created/updated | Auto-plan on dev |
| **Push** | Merge to main | Auto-apply to dev |
| **Manual** | Workflow dispatch | User selects env & action |

## 🔒 Environment Rules

| Environment | Approval | Auto-Deploy | Branch |
|-------------|----------|-------------|--------|
| **dev** | None | ✅ Yes | All |
| **qa** | None | ❌ No | main, develop |
| **uat** | 1 reviewer | ❌ No | main |
| **prod** | 2 reviewers | ❌ No | main |

## 📊 Workflow Steps

```
1. Checkout → 2. AWS Config → 3. Setup TF → 4. Init → 5. Validate → 6. Plan/Apply/Destroy → 7. Summary
```

## 🔧 Quick Fixes

| Problem | Solution |
|---------|----------|
| **State locked** | Wait or cancel stuck workflow |
| **Auth failed** | Check GitHub secrets |
| **Resource exists** | Import or use different name |
| **No changes shown** | Run `terraform refresh` |

## 📝 Git Workflow

```bash
# 1. Branch
git checkout -b feature/my-change

# 2. Change
vim layers/networking/main.tf

# 3. Commit
git add . && git commit -m "feat: description"

# 4. Push
git push origin feature/my-change

# 5. PR → Auto-plan runs

# 6. Merge → Auto-deploys to dev
```

## 🎯 Manual Deployment Flow

```
1. Actions tab
2. Select workflow
3. Run workflow
4. Fill inputs:
   - Environment: dev/qa/uat/prod
   - Action: plan/apply/destroy
5. Click "Run workflow"
6. Monitor logs
7. Verify in AWS
```

## 📚 Documentation Links

| Doc | Purpose |
|-----|---------|
| [CICD.md](CICD.md) | Complete guide (545 lines) |
| [CICD-QUICKSTART.md](CICD-QUICKSTART.md) | 5-minute setup |
| [CICD-ARCHITECTURE.md](CICD-ARCHITECTURE.md) | Visual diagrams |
| [CICD-EXAMPLES.md](CICD-EXAMPLES.md) | Real scenarios |
| [.github/workflows/README.md](../.github/workflows/README.md) | Workflow details |

## 🔐 Required Secrets

```
AWS_ACCESS_KEY_ID          - AWS access key
AWS_SECRET_ACCESS_KEY      - AWS secret key
AWS_REGION (optional)      - Default: us-east-1
```

## ⚡ Emergency Procedures

### Hotfix
```
1. git checkout -b hotfix/fix-name
2. Make critical fix
3. Create PR with HOTFIX label
4. Get expedited approval
5. Deploy immediately
```

### Rollback
```
1. git revert <commit-hash>
2. git push origin main
3. Monitor auto-deployment
OR
4. Manual: Actions → destroy → redeploy old version
```

## 📊 Status Icons

| Icon | Meaning |
|------|---------|
| ✅ | Success |
| ❌ | Failed |
| 🟡 | In Progress |
| ⏸️ | Waiting for Approval |
| ⏭️ | Skipped |

## 🎓 Learning Path

```
1. Read CICD-QUICKSTART.md          (5 min)
2. Complete setup checklist          (5 min)
3. Deploy to dev environment         (10 min)
4. Create test PR                    (15 min)
5. Deploy all layers                 (30 min)
6. Read full CICD.md                 (30 min)
7. Practice rollback                 (15 min)
```

## ⚠️ Important Notes

- ✅ Always plan before apply
- ✅ Review plans carefully
- ✅ Test in dev first
- ✅ Get approvals for prod
- ✅ Monitor deployments
- ✅ Keep documentation updated
- ❌ Never skip plan step
- ❌ Never force-apply without review
- ❌ Never deploy to prod without testing

## 🔍 Troubleshooting Quick Reference

```bash
# View workflow logs
Actions → Run → View logs

# Check Terraform state
terraform state list

# Unlock state
terraform force-unlock <id>

# Refresh state
terraform refresh

# Check AWS resources
aws ec2 describe-vpcs
```

## 📞 Get Help

1. Check docs in `/docs/`
2. Review GitHub Actions logs
3. Slack: #infrastructure
4. Create GitHub issue

## 📈 Success Metrics

| Metric | Target |
|--------|--------|
| Success Rate | >95% |
| Deploy Time | <30 min |
| Rollback Time | <15 min |

## 🎯 Best Practices

```
✅ Use feature branches
✅ Create meaningful commits
✅ Review plans before apply
✅ Progressive deployment (dev→qa→uat→prod)
✅ Monitor after deployment
✅ Document changes
✅ Keep state backed up
✅ Rotate credentials regularly
```

---

**Print this page and keep it handy!**

**Last Updated**: October 2025  
**Version**: 1.0.0
