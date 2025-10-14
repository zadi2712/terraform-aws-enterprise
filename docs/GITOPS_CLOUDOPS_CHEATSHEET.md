# GitOps vs CloudOps - Quick Reference Cheat Sheet

## 🎯 One-Page Quick Reference

---

## Core Comparison

| | GitOps | CloudOps |
|-|--------|----------|
| **Control** | Git Repository | Cloud Provider |
| **Method** | Pull (Operators) | Push (CI/CD) |
| **State** | Git commits | Cloud state |
| **Rollback** | `git revert` | Cloud console/CLI |
| **Audit** | Git history | Cloud logs |
| **Best For** | Kubernetes | Any cloud resource |

---

## Quick Decision Guide

```
Need to deploy?
│
├─ Kubernetes? → YES → Use GitOps
│
└─ Non-K8s (VMs, DBs, etc.)? → YES → Use CloudOps
```

---

## Common Commands

### GitOps (Flux)

```bash
# Bootstrap Flux
flux bootstrap github \
  --owner=org \
  --repository=repo \
  --branch=main \
  --path=clusters/prod

# Check status
flux get all

# Force reconciliation
flux reconcile kustomization webapp

# Suspend/Resume
flux suspend kustomization webapp
flux resume kustomization webapp
```

### GitOps (ArgoCD)

```bash
# Create application
argocd app create webapp \
  --repo https://github.com/org/repo \
  --path k8s \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace production

# Sync application
argocd app sync webapp

# Rollback
argocd app rollback webapp
```

### CloudOps (Terraform)

```bash
# Initialize
terraform init

# Plan changes
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan

# Destroy resources
terraform destroy

# Rollback (revert code, then)
terraform apply
```

### CloudOps (AWS)

```bash
# Deploy CloudFormation
aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name my-stack

# Update ECS service
aws ecs update-service \
  --cluster prod \
  --service webapp \
  --force-new-deployment

# Rollback ECS (to previous task def)
aws ecs update-service \
  --cluster prod \
  --service webapp \
  --task-definition webapp:23
```

---

## Workflow Patterns

### GitOps Workflow

```
1. Developer commits to Git
2. GitOps operator detects change
3. Operator pulls manifests
4. Operator applies to cluster
5. Cluster state = Git state
```

### CloudOps Workflow

```
1. Developer commits code
2. CI/CD pipeline triggers
3. Build and test
4. Deploy to cloud via API
5. Cloud resources updated
```

---

## File Structure Examples

### GitOps Repository

```
repo/
├── apps/
│   ├── frontend/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── backend/
├── infrastructure/
│   ├── namespaces.yaml
│   └── rbac.yaml
└── flux-system/
```

### CloudOps Repository

```
repo/
├── modules/
│   ├── vpc/
│   ├── ecs/
│   └── rds/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── production/
└── global/
```

---

## Pros & Cons (TL;DR)

### GitOps
✅ Git = source of truth  
✅ Easy rollback  
✅ Better audit trail  
✅ Self-healing  
❌ K8s only  
❌ Steeper learning curve  

### CloudOps
✅ Any cloud resource  
✅ Multi-cloud  
✅ Mature tools  
✅ Flexible  
❌ State management  
❌ Complex rollbacks  

---

## When to Use

**Use GitOps:**
- 80%+ Kubernetes workloads
- Need strong audit trail
- Want self-service deployments
- Multiple K8s clusters

**Use CloudOps:**
- Mixed infrastructure
- Heavy use of managed services
- Multi-cloud setup
- Non-containerized apps

**Use Both (Hybrid):**
- CloudOps for infrastructure (VPC, RDS, etc.)
- GitOps for applications (K8s deployments)

---

## Common Issues & Solutions

### GitOps Issues

**Problem:** Operator not syncing  
**Solution:** Check Git credentials, verify permissions
```bash
flux get sources git
kubectl describe gitrepository webapp -n flux-system
```

**Problem:** Secret management  
**Solution:** Use Sealed Secrets or External Secrets
```bash
kubeseal < secret.yaml > sealed-secret.yaml
```

### CloudOps Issues

**Problem:** Terraform state locked  
**Solution:** Force unlock (carefully!)
```bash
terraform force-unlock <lock-id>
```

**Problem:** State drift  
**Solution:** Import or refresh state
```bash
terraform refresh
terraform import aws_instance.web i-1234567890
```

---

## Security Best Practices

### GitOps Security
✅ Use Sealed Secrets for sensitive data  
✅ Enable RBAC in ArgoCD/Flux  
✅ Use SSH keys for Git access  
✅ Implement admission controllers  
✅ Regular security scans  

### CloudOps Security
✅ Use IAM roles, not keys  
✅ Enable MFA for human access  
✅ Store secrets in Secrets Manager  
✅ Encrypt Terraform state  
✅ Use separate AWS accounts per env  

---

## Monitoring & Troubleshooting

### GitOps Monitoring

```bash
# Check Flux status
flux get all

# View reconciliation logs
kubectl logs -n flux-system \
  deployment/kustomize-controller

# Check application status (ArgoCD)
argocd app get webapp
argocd app logs webapp
```

### CloudOps Monitoring

```bash
# Check Terraform state
terraform show

# View CloudFormation events
aws cloudformation describe-stack-events \
  --stack-name my-stack

# ECS service status
aws ecs describe-services \
  --cluster prod \
  --services webapp
```

---

## Learning Resources

### GitOps
- [Flux Docs](https://fluxcd.io/docs/)
- [ArgoCD Docs](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://opengitops.dev/)

### CloudOps
- [Terraform Registry](https://registry.terraform.io/)
- [AWS Well-Architected](https://aws.amazon.com/architecture/well-architected/)
- [Azure Best Practices](https://docs.microsoft.com/en-us/azure/architecture/)

---

## Quick Tips

### GitOps Tips
💡 Keep manifests in separate repo from app code  
💡 Use Kustomize for environment differences  
💡 Tag Git commits for easy rollback  
💡 Enable notifications for failed syncs  
💡 Use preview environments for testing  

### CloudOps Tips
💡 Always use remote state with locking  
💡 Use workspaces for environments  
💡 Tag all resources consistently  
💡 Run `terraform plan` in CI/CD  
💡 Keep modules versioned  

---

## Emergency Procedures

### GitOps Emergency Rollback
```bash
# Option 1: Git revert
git revert HEAD
git push origin main
# Flux auto-applies

# Option 2: Manual rollback
kubectl rollout undo deployment/webapp
# Then update Git to match

# Option 3: Disable sync
flux suspend kustomization webapp
# Make manual fixes
flux resume kustomization webapp
```

### CloudOps Emergency Rollback
```bash
# Terraform rollback
git checkout <previous-commit>
terraform apply -auto-approve

# AWS ECS rollback
aws ecs update-service \
  --cluster prod \
  --service webapp \
  --task-definition webapp:PREVIOUS

# CloudFormation rollback
aws cloudformation rollback-stack \
  --stack-name my-stack
```

---

## Deployment Checklist

### GitOps Deployment
- [ ] Update manifest files
- [ ] Create Pull Request
- [ ] Code review approved
- [ ] Merge to main branch
- [ ] Verify operator sync
- [ ] Check pod status
- [ ] Monitor logs
- [ ] Verify application health

### CloudOps Deployment
- [ ] Update Terraform code
- [ ] Run `terraform plan`
- [ ] Review plan output
- [ ] Get approval (if required)
- [ ] Run `terraform apply`
- [ ] Verify resources created
- [ ] Check application health
- [ ] Update documentation

---

## Comparison Matrix

| Feature | GitOps | CloudOps |
|---------|--------|----------|
| Learning Curve | ⭐⭐ | ⭐⭐⭐⭐ |
| K8s Support | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| Cloud Resources | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| Rollback Speed | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| Security | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Audit Trail | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| Flexibility | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Multi-Cloud | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

---

**Print this page and keep it at your desk!** 📎

**Last Updated:** October 13, 2025  
**Version:** 1.0
