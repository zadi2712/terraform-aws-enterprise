# Infrastructure Drift Changelog

## Purpose

This file tracks all infrastructure drift incidents, their investigations, and resolutions.

## Format

```
YYYY-MM-DD HH:MM | Layer/Environment | Description | Action Taken | Author | Ticket
```

---

## Drift Incidents Log

### 2024-10

**2024-10-20 16:00** - Initial drift detection pipeline deployed

---

## Template for New Entries

```markdown
### YYYY-MM-DD

**YYYY-MM-DD HH:MM** | layer/environment | Brief description of drift

**What Changed:**
- Resource: aws_xxx
- Attribute: xxx
- Old Value: xxx
- New Value: xxx

**Root Cause:**
- Manual change in AWS Console by [person/process]
- Emergency hotfix for [issue]
- Other automation tool

**Investigation:**
- CloudTrail showed: [findings]
- Change was made by: [principal]
- Reason: [why]

**Resolution:**
- [ ] Updated Terraform code to match AWS
- [ ] Reverted AWS changes to match Terraform
- [ ] Imported new resource into Terraform

**Approved By:** [name]
**Resolved By:** [name]
**Ticket:** [link to GitHub issue]

---
```

## Example Entries

<!--

### 2024-10-20

**2024-10-20 14:30** | compute/prod | EC2 instance type changed

**What Changed:**
- Resource: aws_instance.bastion
- Attribute: instance_type
- Old Value: t3.micro
- New Value: t3.small

**Root Cause:**
- Manual change in AWS Console to address performance issues

**Investigation:**
- CloudTrail showed change by ops-team IAM user
- Change made during incident response
- Improved bastion performance during peak load

**Resolution:**
- ✅ Updated Terraform code to use t3.small
- Approved as permanent change
- Committed in PR #123

**Approved By:** Tech Lead
**Resolved By:** DevOps Team
**Ticket:** #456

---

**2024-10-21 09:15** | security/prod | KMS key policy modified

**What Changed:**
- Resource: aws_kms_key.main
- Attribute: policy
- Old Value: [policy v1]
- New Value: [policy v2]

**Root Cause:**
- Unauthorized manual change

**Investigation:**
- Policy change added overly broad permissions
- Not approved through change management
- Security risk identified

**Resolution:**
- ✅ Reverted AWS changes via terraform apply
- Restored secure key policy
- Investigated access and restricted Console permissions

**Approved By:** Security Team
**Resolved By:** Security Team
**Ticket:** #457

-->

---

## Drift Prevention Measures

After each drift incident, consider:

1. **Policy Updates**
   - Restrict AWS Console access
   - Require Terraform for all changes
   - Document exceptions

2. **Process Improvements**
   - Update change management process
   - Require drift check before deployments
   - Automate more workflows

3. **Technical Controls**
   - Add lifecycle ignore_changes where appropriate
   - Implement Service Control Policies (SCPs)
   - Enable AWS Config rules

4. **Training**
   - Educate team on Terraform-first approach
   - Document emergency change procedures
   - Share drift incidents in team meetings

---

## Statistics

- **Total Drift Incidents:** 0
- **Most Frequent Layer:** N/A
- **Most Frequent Environment:** N/A
- **Average Time to Resolution:** N/A
- **Last Incident:** Never

---

**Maintained by:** Platform Team  
**Last Updated:** 2024-10-20
