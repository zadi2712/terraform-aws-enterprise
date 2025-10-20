# Architecture Decision: IAM Role Management

## Decision Summary

**Date:** October 20, 2025  
**Status:** ✅ Implemented  
**Decision:** IAM roles should be managed by the modules that need them, not centralized in the security layer.

---

## Context

We had redundant IAM role creation:
- **Security Layer** was creating a shared ECS task execution role
- **ECS Module** can create its own task execution and task roles

This created:
- Duplication
- Potential naming conflicts
- Unclear ownership
- Less flexibility

---

## Decision

### ✅ **Adopted Approach: Decentralized IAM Management**

Each module manages its own IAM resources.

### Architecture Principles

```
┌─────────────────────────────────────────────┐
│         Security Layer                       │
│  Focus: Encryption & Security Primitives    │
│  • KMS Keys (Main, RDS, S3, EBS)            │
│  • Key Policies                             │
│  • Security Configurations                  │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│         Compute Layer                        │
│  • ECS Cluster + IAM Roles                  │
│  • EKS Cluster + IAM Roles                  │
│  • Lambda + IAM Roles                       │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│         Database Layer                       │
│  • RDS + IAM Roles (if needed)              │
│  • DynamoDB + IAM Roles                     │
└─────────────────────────────────────────────┘
```

---

## Rationale

### Why This Approach?

#### ✅ **Pros**

1. **Better Encapsulation**
   - Each module is self-contained
   - Clear ownership and responsibility
   - Easier to understand dependencies

2. **More Flexible**
   - Different services can have different IAM permissions
   - Multiple ECS clusters can have unique roles
   - Environment-specific permissions

3. **Avoids Conflicts**
   - No name collisions
   - No duplicate resources
   - Clear resource lifecycle

4. **Easier Testing**
   - Modules can be tested independently
   - IAM permissions scoped to module

5. **Better Reusability**
   - Modules are portable across projects
   - Self-contained dependencies

#### ❌ **Cons of Centralized IAM**

1. **Tight Coupling**
   - Security layer knows about all services
   - Changes require security layer updates

2. **Less Flexible**
   - One-size-fits-all IAM policies
   - Harder to customize per service

3. **Scalability Issues**
   - Security layer becomes bloated
   - Harder to maintain

---

## Implementation

### Security Layer - ONLY Encryption

```hcl
# layers/security/main.tf

# ✅ KMS Keys
module "kms_main" { ... }
module "kms_rds" { ... }
module "kms_s3" { ... }
module "kms_ebs" { ... }

# ❌ NO SERVICE-SPECIFIC IAM ROLES
# Removed: aws_iam_role.ecs_task_execution
```

### ECS Module - Owns Its IAM

```hcl
# modules/ecs/main.tf

# ✅ Task Execution Role (for ECS agent)
resource "aws_iam_role" "task_execution" {
  count = var.create_task_execution_role ? 1 : 0
  # ...
}

# ✅ Task Role (for application)
resource "aws_iam_role" "task" {
  count = var.create_task_role ? 1 : 0
  # ...
}
```

### Compute Layer - Enables IAM Creation

```hcl
# layers/compute/main.tf

module "ecs_cluster" {
  source = "../../../modules/ecs"
  
  # ✅ Let ECS module create its own IAM roles
  create_task_execution_role = true
  create_task_role           = true
}
```

---

## When to Use Centralized IAM?

### Create an IAM Module ONLY IF:

1. **Truly Cross-Cutting Roles**
   - Shared by multiple unrelated services
   - Example: Cross-account access roles

2. **Organization-Wide Patterns**
   - Standard role templates
   - Compliance-mandated roles

3. **Many Similar Roles**
   - 10+ roles following same pattern
   - Worth abstracting into module

### Example: Future IAM Module (if needed)

```hcl
# modules/iam/
# Only if you have:
# - 10+ similar roles
# - Complex organization-wide patterns
# - Compliance requirements

module "cross_account_role" {
  source = "../../modules/iam"
  
  role_name    = "CrossAccountAccess"
  assume_roles = ["arn:aws:iam::123456789012:root"]
  policies     = ["ReadOnlyAccess"]
}
```

---

## Best Practices

### ✅ DO

1. **Module Owns Its IAM**
   ```hcl
   # ECS module creates ECS roles
   # Lambda module creates Lambda roles
   # RDS module creates RDS roles (if needed)
   ```

2. **Security Layer = Encryption**
   ```hcl
   # KMS keys only
   # Secret encryption configurations
   # Security primitives
   ```

3. **Use Variables for Control**
   ```hcl
   variable "create_task_execution_role" {
     description = "Create IAM role or use existing"
     type        = bool
     default     = true
   }
   ```

4. **Document IAM Permissions**
   - Each module's README lists IAM resources
   - Clear documentation of permissions

### ❌ DON'T

1. **Don't Centralize Service IAM**
   ```hcl
   # ❌ BAD: Security layer creating ECS roles
   resource "aws_iam_role" "ecs_role" { ... }
   ```

2. **Don't Share Roles Unnecessarily**
   ```hcl
   # ❌ BAD: One role for everything
   # Different services need different permissions
   ```

3. **Don't Create IAM Module Prematurely**
   - Wait until you have real duplication
   - Don't over-engineer for 1-2 roles

---

## Migration Guide

### If You Had the Old Setup

1. **Remove from Security Layer**
   ```bash
   # Already done - IAM resources removed
   terraform plan  # Will show removal of IAM role
   ```

2. **Enable in Service Modules**
   ```hcl
   # layers/compute/main.tf
   module "ecs_cluster" {
     create_task_execution_role = true
     create_task_role           = true
   }
   ```

3. **Apply Changes**
   ```bash
   # Security layer
   cd layers/security/environments/dev
   terraform apply  # Removes old role
   
   # Compute layer
   cd layers/compute/environments/dev
   terraform apply  # Creates new roles
   ```

---

## Exception: When to Centralize

### Scenario: Cross-Account Access

```hcl
# layers/security/main.tf
# ✅ OK: Truly security-related, cross-cutting concern

resource "aws_iam_role" "cross_account_read" {
  name = "CrossAccountReadOnly"
  
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        AWS = "arn:aws:iam::987654321098:root"
      }
    }]
  })
}
```

This is acceptable because:
- Not service-specific
- Security/compliance requirement
- Used across multiple layers
- Truly belongs in security layer

---

## Current State

### Security Layer Responsibilities

✅ **What It Does:**
- KMS key management (main, RDS, S3, EBS)
- Encryption configuration
- Security primitives
- SSM parameter storage for KMS keys

❌ **What It Doesn't Do:**
- Service-specific IAM roles
- Application permissions
- Service authentication

### Module Responsibilities

Each module manages:
- Its own IAM roles
- Its own policies
- Its own service authentication

---

## Summary

**Decision:** Decentralized IAM management per module

**Security Layer:** Focus on encryption (KMS) only

**Service Modules:** Own their IAM resources

**Benefits:**
- Better encapsulation
- More flexible
- Easier to maintain
- Clearer ownership

**When to Centralize:**
- Only for truly cross-cutting IAM concerns
- Cross-account access roles
- Organization-wide compliance roles

---

## References

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Terraform Module Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/part1.html)
- [Well-Architected Framework - Security](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/)

---

**Status:** ✅ Implemented and Documented

