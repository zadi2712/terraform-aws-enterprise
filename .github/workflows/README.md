# GitHub Actions Workflows

This directory contains all GitHub Actions workflow definitions for automated infrastructure deployment.

## 📁 Directory Structure

```
.github/workflows/
├── reusable-terraform.yml       # Core reusable workflow (foundation)
├── branch-based-deploy.yml      # 🆕 Auto-deploy based on branch (NEW!)
├── deploy-networking.yml        # Networking layer (VPC, Subnets, Endpoints)
├── deploy-security.yml          # Security layer (IAM, KMS, Security Groups)
├── deploy-compute.yml           # Compute layer (EKS, EC2, ASG)
├── deploy-database.yml          # Database layer (RDS, DynamoDB)
├── deploy-storage.yml           # Storage layer (S3, EFS)
├── deploy-dns.yml               # DNS layer (Route53)
├── deploy-monitoring.yml        # Monitoring layer (CloudWatch)
└── deploy-all-layers.yml        # Orchestration workflow (all layers)
```

## 🎯 Workflow Overview

### Core Workflow (Reusable)

**File**: `reusable-terraform.yml`

This is the foundation that all other workflows build upon. It contains all the Terraform logic and is called by layer-specific workflows using the `workflow_call` trigger.

**Key Features**:
- AWS credential configuration
- Terraform initialization with backend configuration
- Format checking and validation
- Plan generation with artifact upload
- Apply/destroy operations
- PR commenting with plan output
- Comprehensive step summaries

### 🆕 Branch-Based Auto Deployment Workflow

**File**: `branch-based-deploy.yml`

**NEW!** Automatically deploys to environments based on which branch you push to. This provides a GitOps-style deployment flow.

**Branch Mapping**:
- **`main`** branch → Auto-deploys to **PROD** + **UAT** environments
- **`dev`** branch → Auto-deploys to **DEV** environment  
- **`staging`** branch → Auto-deploys to **QA** environment

**Key Features**:
- Automatic environment selection based on branch
- All 7 layers deployed sequentially with proper dependency order
- Concurrent deployments to PROD and UAT when pushing to main
- Path-based filtering (ignores docs, markdown files)
- Comprehensive deployment summary with status for each layer
- Concurrency control to prevent overlapping deployments

**Usage**:
```bash
# Deploy to DEV
git checkout dev
git commit -m "Update infrastructure"
git push origin dev  # Automatically deploys to dev

# Deploy to QA
git checkout staging
git merge dev
git push origin staging  # Automatically deploys to qa

# Deploy to PROD + UAT
git checkout main
git merge staging
git push origin main  # Automatically deploys to prod AND uat
```

**Workflow Behavior**:
1. **Determines target environment(s)** based on branch name
2. **Deploys all layers sequentially** in dependency order:
   - networking → security → storage → database → compute → dns → monitoring
3. **Runs apply action** automatically (not just plan)
4. **Generates comprehensive summary** with status for each layer and environment

**When to use**:
- ✅ Standard development workflow (dev → staging → main)
- ✅ GitOps-style deployments
- ✅ CI/CD automation
- ✅ When you want automatic deployments on git push

**When NOT to use**:
- ❌ For testing individual layers (use layer-specific workflows)
- ❌ For running only plan without apply (use manual workflows)
- ❌ For destroy operations (use manual workflows with destroy action)

### Layer Workflows

Each layer has its own workflow that calls the reusable workflow with layer-specific parameters.

**Pattern**:
```yaml
jobs:
  deploy:
    uses: ./.github/workflows/reusable-terraform.yml
    with:
      layer: <layer-name>
      environment: ${{ inputs.environment }}
      action: ${{ inputs.action }}
```

### Orchestration Workflow

**File**: `deploy-all-layers.yml`

Deploys all layers sequentially in dependency order. Useful for:
- Initial environment setup
- Complete infrastructure refresh
- Disaster recovery scenarios

**Dependency Order**:
1. networking → 2. security → 3. storage → 4. database → 5. compute → 6. dns → 7. monitoring

## 🚀 Quick Start

### Deploy Single Layer Manually

1. Go to **Actions** tab
2. Select desired layer workflow (e.g., "Deploy Networking Layer")
3. Click "Run workflow"
4. Fill in parameters:
   - **Environment**: dev/qa/uat/prod
   - **Action**: plan/apply/destroy
   - **Terraform Version**: (optional)
5. Click "Run workflow"

### Deploy via Pull Request

1. Create branch: `git checkout -b feature/my-change`
2. Make changes to layer files
3. Commit and push
4. Create PR
5. Automatic plan runs and comments on PR
6. Review plan output
7. Merge PR → Auto-deploys to dev

### Deploy All Layers

1. Go to **Actions** tab
2. Select "Deploy All Layers"
3. Click "Run workflow"
4. Select environment and action
5. Optional: specify layers to skip
6. Monitor sequential deployment

## 🔧 Triggers

### Manual Trigger (workflow_dispatch)

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, qa, uat, prod]
      action:
        type: choice
        options: [plan, apply, destroy]
```

**Use Cases**:
- Deploying to specific environments
- Running destroy operations
- Testing configuration changes
- Production deployments

### Push Trigger

**Branch-Based Auto Deployment** (`branch-based-deploy.yml`):
```yaml
on:
  push:
    branches:
      - main    # → deploys to prod + uat
      - dev     # → deploys to dev
      - staging # → deploys to qa
    paths-ignore:
      - '**.md'
      - 'docs/**'
```

**Layer-Specific Workflows**:
```yaml
on:
  push:
    branches: [main, develop]
    paths:
      - 'layers/<layer>/**'
      - 'modules/**'
```

**Behavior**:
- Branch-based: Automatically applies changes to designated environment(s)
- Layer-specific: Only triggers when relevant files change

### Pull Request Trigger

```yaml
on:
  pull_request:
    branches: [main, develop]
    paths:
      - 'layers/<layer>/**'
```

**Behavior**:
- Automatically runs plan on dev environment
- Posts plan output as PR comment
- Helps reviewers understand infrastructure changes

## 🔒 Security Features

### Least Privilege Permissions

```yaml
permissions:
  contents: read        # Read repository code
  pull-requests: write  # Comment on PRs
  issues: write         # Create/update issues
```

### Environment Protection

- **dev**: No restrictions
- **qa**: Manual approval recommended
- **uat**: 1 required reviewer
- **prod**: 2 required reviewers + wait timer

### Concurrency Control

```yaml
concurrency:
  group: <layer>-${{ inputs.environment }}
  cancel-in-progress: false
```

Prevents multiple simultaneous deployments to the same environment.

### Secrets Management

Required secrets (configured in GitHub Settings):
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION` (optional)

## 📊 Workflow Status

### View Workflow Runs

**In GitHub**:
- Go to **Actions** tab
- Select workflow from sidebar
- View run history and status

### Workflow Badges

Add to your README:

```markdown
![Deploy Networking](https://github.com/<org>/<repo>/actions/workflows/deploy-networking.yml/badge.svg)
![Deploy Compute](https://github.com/<org>/<repo>/actions/workflows/deploy-compute.yml/badge.svg)
```

## 🛠️ Customization

### Adding a New Layer

1. **Create layer directory**:
   ```bash
   mkdir -p layers/new-layer/environments/{dev,qa,uat,prod}
   ```

2. **Copy workflow template**:
   ```bash
   cp .github/workflows/deploy-networking.yml \
      .github/workflows/deploy-new-layer.yml
   ```

3. **Update workflow**:
   - Change `name:` to match new layer
   - Update `paths:` to watch new layer files
   - Update `layer:` parameter in reusable workflow call

4. **Add to orchestration** (if needed):
   Edit `deploy-all-layers.yml` to include new layer in sequence

### Modifying Terraform Version

Change default version in workflow:
```yaml
inputs:
  terraform_version:
    default: '1.9.0'  # Change this
```

### Adding Custom Steps

Add before/after deployment hooks in `reusable-terraform.yml`:

```yaml
- name: Pre-deployment Validation
  run: |
    # Custom validation logic
    ./scripts/validate.sh
    
- name: Post-deployment Tests
  run: |
    # Smoke tests
    ./scripts/test.sh ${{ inputs.environment }}
```

## 📝 Best Practices

### Development Workflow

**Option 1: Branch-Based Auto Deployment (Recommended)**

1. ✅ Create feature branch from `dev`
2. ✅ Make focused, atomic changes
3. ✅ Push to `dev` branch → Auto-deploys to DEV
4. ✅ Test in DEV environment
5. ✅ Merge to `staging` → Auto-deploys to QA
6. ✅ Test in QA environment
7. ✅ Get approval and merge to `main` → Auto-deploys to PROD + UAT
8. ✅ Verify in production

**Option 2: Manual Workflow (For specific scenarios)**

1. ✅ Always create feature branch
2. ✅ Make focused, atomic changes
3. ✅ Create PR and review plan
4. ✅ Get approval before merging
5. ✅ Monitor auto-deployment to dev
6. ✅ Manually promote to higher environments

### Deployment Strategy

**GitOps Branch-Based (NEW - Recommended)**:
```
dev branch (push) → Auto-deploy DEV
     ↓
staging branch (merge from dev) → Auto-deploy QA
     ↓
main branch (merge from staging) → Auto-deploy PROD + UAT
```

**Traditional Manual**:
```
Feature Branch → PR (plan) → Main (auto-deploy dev) → Manual (qa) → Manual (uat) → Manual (prod)
```

### Error Handling

- Check logs in GitHub Actions
- Review Terraform error output
- Use plan before apply
- Test in dev before prod
- Keep state backups

## 🔍 Troubleshooting

### Common Issues

**Issue**: Workflow doesn't trigger
- **Fix**: Check file paths in workflow trigger
- **Fix**: Ensure changes match path filters

**Issue**: AWS credentials failed
- **Fix**: Verify GitHub secrets are set correctly
- **Fix**: Check IAM permissions

**Issue**: State lock error
- **Fix**: Wait for lock to release
- **Fix**: Check for hung workflows and cancel

**Issue**: Plan shows unexpected changes
- **Fix**: Check for manual changes in AWS Console
- **Fix**: Run `terraform refresh` locally
- **Fix**: Review drift detection

## 📚 Documentation

- **Comprehensive Guide**: [`/docs/CICD.md`](../../docs/CICD.md)
- **Deployment Runbook**: [`/docs/DEPLOYMENT_RUNBOOK.md`](../../docs/DEPLOYMENT_RUNBOOK.md)
- **Quick Start**: [`/docs/QUICKSTART.md`](../../docs/QUICKSTART.md)

## 🤝 Contributing

When adding or modifying workflows:

1. Follow existing patterns and naming conventions
2. Add comprehensive comments
3. Test in dev environment first
4. Update documentation
5. Add to CICD.md if introducing new features
6. Create PR with workflow changes

## 📞 Support

For issues or questions:
- Review documentation in `/docs/CICD.md`
- Check GitHub Actions logs
- Contact DevOps team on Slack #infrastructure
- Create GitHub issue with workflow run link

---

**Maintained By**: Platform Engineering Team  
**Last Updated**: October 2025
