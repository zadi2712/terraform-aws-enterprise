# Git Flow Quick Reference Guide

## 🚀 Daily Workflow Cheatsheet

### Starting New Work

```bash
# 1. Get latest changes
git checkout develop
git pull origin develop

# 2. Create feature branch
git checkout -b feature/GUS-12345-short-description

# 3. Do your work, commit frequently
git add .
git commit -m "GUS-12345: feat: Add user authentication"

# 4. Push and create PR
git push origin feature/GUS-12345-short-description
```

### Branch Naming Patterns

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feature/GUS-{ID}-{description}` | `feature/GUS-12345-user-login` |
| Bug Fix | `bugfix/GUS-{ID}-{description}` | `bugfix/GUS-12346-fix-timeout` |
| Hotfix | `hotfix/GUS-{ID}-{description}` | `hotfix/GUS-12347-security-patch` |
| Release | `release/v{MAJOR}.{MINOR}.{PATCH}` | `release/v1.2.0` |

### Commit Message Template

```
GUS-{TICKET-ID}: {type}: {Short description}

{Optional detailed description}

References: GUS-{TICKET-ID}
```

**Types**: feat, fix, docs, style, refactor, test, chore, perf, ci, build

### Before Creating a PR

```markdown
- [ ] All commits reference GUS ticket
- [ ] Code is self-reviewed
- [ ] Tests pass locally
- [ ] Branch is up-to-date with develop
- [ ] No merge conflicts
- [ ] Linting passes
```

## 🌍 Environment Flow

```
DEV (feature/*) → QA (develop) → UAT (release/*) → PROD (main)
    ↓                ↓                ↓              ↓
  Auto            Auto            Manual         Manual
 Deploy          Deploy          Approval       Approval
```

## ⚡ Common Commands

### Update Your Branch
```bash
git fetch origin
git rebase origin/develop
# Fix conflicts if any
git push origin feature/GUS-12345 --force-with-lease
```

### Undo Last Commit (Local Only)
```bash
git reset HEAD~1  # Keep changes
git reset --hard HEAD~1  # Discard changes
```

### Stash Changes
```bash
git stash  # Save changes
git stash pop  # Restore changes
git stash list  # View stashes
```

## 🔥 Emergency Hotfix

```bash
# 1. Branch from main
git checkout main
git pull origin main
git checkout -b hotfix/GUS-12347-critical-fix

# 2. Fix and test
git commit -m "GUS-12347: fix: Critical security patch"

# 3. Merge to main
git checkout main
git merge --no-ff hotfix/GUS-12347-critical-fix
git tag -a v1.2.1 -m "Hotfix: Security patch"

# 4. Merge back to develop
git checkout develop
git merge --no-ff hotfix/GUS-12347-critical-fix

# 5. Push everything
git push origin main develop --tags
```

## 📋 PR Checklist

```markdown
- [ ] GUS ticket linked
- [ ] Acceptance criteria met
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No hardcoded secrets
- [ ] Error handling appropriate
- [ ] Performance considered
```

## 🔄 Release Process

### Creating a Release
```bash
# 1. Create release branch from develop
git checkout develop
git pull origin develop
git checkout -b release/v1.2.0

# 2. Update version numbers
# Edit package.json, version files, etc.
git commit -m "GUS-12350: chore: Bump version to 1.2.0"

# 3. Deploy to UAT
# CI/CD handles deployment

# 4. After UAT approval, merge to main
git checkout main
git merge --no-ff release/v1.2.0
git tag -a v1.2.0 -m "Release version 1.2.0"

# 5. Merge back to develop
git checkout develop
git merge --no-ff release/v1.2.0

# 6. Push and cleanup
git push origin main develop --tags
git branch -d release/v1.2.0
```

## 🚨 Rollback Quick Actions

### Production Rollback
```bash
# Option 1: Blue-Green (Instant)
# → Switch traffic back to blue environment

# Option 2: Revert Commit
git checkout main
git revert <bad-commit-hash>
git push origin main
# Trigger deployment

# Option 3: Previous Tag
git checkout v1.1.0
# Trigger deployment
```

## 🔍 GUS Status Mapping

| Git Action | GUS Status |
|------------|------------|
| Branch created | In Progress |
| PR created | In Review |
| PR approved | Approved |
| Merged to develop | In QA |
| Deployed to UAT | In UAT |
| Deployed to PROD | Deployed |

## 📞 Quick Contacts

- **DevOps Lead**: devops-lead@company.com
- **On-Call**: oncall@company.com
- **Slack**: #devops-support
- **Emergency**: +1-xxx-xxx-xxxx

## 🎯 Quality Gates

| Check | Threshold |
|-------|-----------|
| Code Coverage | ≥ 80% |
| Security Vulnerabilities | 0 Critical/High |
| Code Quality (SonarQube) | A or B |
| Test Success Rate | 100% |

## ⚙️ Deployment Windows

- **DEV**: Anytime
- **QA**: Business hours (9 AM - 5 PM)
- **UAT**: Tuesdays & Thursdays (2 PM - 4 PM)
- **PROD**: Thursdays (8 PM - 10 PM)
- **Emergency**: Anytime with approval

---

**Quick Tip**: Bookmark this page for fast access during development!

**Full Documentation**: See `Git_Policy_and_Branching_Strategy.md` for complete details.
