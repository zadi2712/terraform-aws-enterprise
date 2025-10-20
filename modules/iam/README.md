# IAM Module

## Description

Enterprise IAM module for managing cross-cutting IAM concerns including cross-account roles, OIDC/SAML providers, organization-wide policies, and user management.

**Important:** This module is for **organization-wide and cross-cutting IAM** only. Service-specific IAM roles (ECS, Lambda, RDS, etc.) should be managed by their respective modules. See [Architecture Decision](../../ARCHITECTURE_DECISION_IAM.md) for details.

## When to Use This Module

### ✅ USE for:

- **Cross-Account Access Roles** - For accessing resources in other AWS accounts
- **OIDC Providers** - For GitHub Actions, GitLab CI/CD
- **SAML Providers** - For SSO integration
- **Organization-Wide Policies** - Compliance, security policies
- **IAM Groups** - For organizing user permissions
- **Human Users** - When SSO is not available (not recommended)
- **Audit Roles** - For compliance and auditing
- **Break-Glass Roles** - For emergency access

### ❌ DON'T USE for:

- **ECS Task Roles** - Use ECS module
- **Lambda Execution Roles** - Use Lambda module  
- **EC2 Instance Profiles** - Use EC2 module
- **RDS Service Roles** - Use RDS module

## Features

- **IAM Roles**: With trust policies and policy attachments
- **IAM Policies**: Custom and managed policy support
- **OIDC Providers**: For CI/CD integration (GitHub Actions, etc.)
- **SAML Providers**: For enterprise SSO
- **IAM Groups**: For user management
- **IAM Users**: For programmatic/console access
- **Password Policy**: Account-wide password requirements
- **Multiple Attachments**: Managed, custom, and inline policies

## Resources Created

- `aws_iam_role` - IAM roles
- `aws_iam_policy` - Custom IAM policies
- `aws_iam_role_policy` - Inline policies
- `aws_iam_role_policy_attachment` - Policy attachments
- `aws_iam_openid_connect_provider` - OIDC providers
- `aws_iam_saml_provider` - SAML providers
- `aws_iam_group` - IAM groups
- `aws_iam_user` - IAM users
- `aws_iam_access_key` - Access keys
- `aws_iam_account_password_policy` - Password policy

## Usage

### Cross-Account Access Role

```hcl
module "cross_account_iam" {
  source = "../../modules/iam"

  roles = {
    cross_account_read = {
      name        = "CrossAccountReadOnly"
      description = "Read-only access from audit account"
      
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            AWS = "arn:aws:iam::123456789012:root"  # Audit account
          }
          Condition = {
            StringEquals = {
              "sts:ExternalId" = "unique-external-id"
            }
          }
        }]
      })
      
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/ReadOnlyAccess"
      ]
      
      max_session_duration = 28800  # 8 hours
    }
  }

  tags = {
    Purpose = "cross-account-access"
  }
}
```

### GitHub Actions OIDC Integration

```hcl
module "github_oidc" {
  source = "../../modules/iam"

  # OIDC Provider for GitHub
  oidc_providers = {
    github = {
      url            = "https://token.actions.githubusercontent.com"
      client_id_list = ["sts.amazonaws.com"]
      thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
    }
  }

  # Role for GitHub Actions
  roles = {
    github_actions = {
      name        = "GitHubActionsRole"
      description = "Role for GitHub Actions deployments"
      
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Principal = {
            Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
          }
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            }
            StringLike = {
              "token.actions.githubusercontent.com:sub" = "repo:myorg/myrepo:*"
            }
          }
        }]
      })
      
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/PowerUserAccess"
      ]
    }
  }

  tags = {
    Purpose = "cicd"
  }
}
```

### Custom Policies

```hcl
module "custom_policies" {
  source = "../../modules/iam"

  policies = {
    s3_app_access = {
      name        = "S3AppBucketAccess"
      description = "Access to application S3 buckets"
      
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          Resource = "arn:aws:s3:::myapp-*/*"
        }]
      })
    }
    
    ecr_pull = {
      name        = "ECRPullImages"
      description = "Pull images from ECR"
      
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Action = [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage"
          ]
          Resource = "*"
        }]
      })
    }
  }

  # Use these policies in roles
  roles = {
    app_deployment = {
      name = "AppDeploymentRole"
      
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "codebuild.amazonaws.com"
          }
        }]
      })
      
      custom_policy_attachments = ["s3_app_access", "ecr_pull"]
    }
  }
}
```

### IAM Groups and Users

```hcl
module "user_management" {
  source = "../../modules/iam"

  # IAM Groups
  groups = {
    developers = {
      name = "Developers"
      policy_arns = [
        "arn:aws:iam::aws:policy/PowerUserAccess"
      ]
    }
    
    readonly = {
      name = "ReadOnlyUsers"
      policy_arns = [
        "arn:aws:iam::aws:policy/ReadOnlyAccess"
      ]
    }
  }

  # IAM Users
  users = {
    john_doe = {
      name   = "john.doe"
      groups = ["developers"]
      
      tags = {
        Team = "engineering"
      }
    }
    
    audit_user = {
      name        = "audit.user"
      groups      = ["readonly"]
      create_access_key = true  # For API access
    }
  }

  # Password policy
  configure_password_policy = true
  
  password_policy = {
    minimum_password_length      = 14
    require_symbols              = true
    max_password_age             = 90
    password_reuse_prevention    = 24
  }

  tags = {
    ManagedBy = "terraform"
  }
}
```

### Audit Role

```hcl
module "audit_role" {
  source = "../../modules/iam"

  roles = {
    security_audit = {
      name        = "SecurityAuditRole"
      description = "Role for security audits"
      
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            AWS = [
              "arn:aws:iam::987654321098:root",  # Security account
              "arn:aws:iam::123456789012:root"   # Audit account
            ]
          }
          Condition = {
            StringEquals = {
              "sts:ExternalId" = "audit-external-id-2024"
            }
          }
        }]
      })
      
      managed_policy_arns = [
        "arn:aws:iam::aws:policy/SecurityAudit",
        "arn:aws:iam::aws:policy/ViewOnlyAccess"
      ]
      
      max_session_duration = 43200  # 12 hours
    }
  }

  tags = {
    Purpose = "security-audit"
  }
}
```

## Inputs

### Roles

| Name | Description | Type | Default |
|------|-------------|------|---------|
| roles | Map of IAM roles to create | map(object) | `{}` |

**Role Object:**
- `name` - Role name
- `description` - Role description
- `assume_role_policy` - Trust policy JSON
- `max_session_duration` - Max session duration (seconds)
- `managed_policy_arns` - AWS managed policy ARNs
- `custom_policy_attachments` - Custom policy keys to attach
- `inline_policies` - Map of inline policies

### Policies

| Name | Description | Type | Default |
|------|-------------|------|---------|
| policies | Map of custom IAM policies | map(object) | `{}` |

### OIDC Providers

| Name | Description | Type | Default |
|------|-------------|------|---------|
| oidc_providers | Map of OIDC providers | map(object) | `{}` |

### Groups & Users

| Name | Description | Type | Default |
|------|-------------|------|---------|
| groups | Map of IAM groups | map(object) | `{}` |
| users | Map of IAM users | map(object) | `{}` |

### Password Policy

| Name | Description | Type | Default |
|------|-------------|------|---------|
| configure_password_policy | Enable password policy | bool | `false` |
| password_policy | Password requirements | object | See defaults |

## Outputs

| Name | Description |
|------|-------------|
| role_arns | Map of role ARNs |
| role_names | Map of role names |
| policy_arns | Map of custom policy ARNs |
| oidc_provider_arns | Map of OIDC provider ARNs |
| group_names | Map of group names |
| user_names | Map of user names |
| iam_summary | Summary of resources created |

## Best Practices

### 1. Use External IDs for Cross-Account Access

```hcl
Condition = {
  StringEquals = {
    "sts:ExternalId" = "unique-random-string"
  }
}
```

### 2. Set Maximum Session Duration

```hcl
max_session_duration = 3600  # 1 hour for production
# Increase for trusted roles: 43200 (12 hours)
```

### 3. Use Permissions Boundaries

```hcl
roles = {
  developer = {
    name = "DeveloperRole"
    permissions_boundary = "arn:aws:iam::aws:policy/PowerUserAccess"
    # ...
  }
}
```

### 4. Prefer IAM Identity Center (SSO)

```hcl
# ✅ Use AWS IAM Identity Center for human access
# ❌ Avoid creating IAM users

# Only create users when absolutely necessary
users = {}  # Prefer empty
```

### 5. Tag Everything

```hcl
tags = {
  Purpose     = "cross-account-access"
  Owner       = "security-team"
  CostCenter  = "security"
  Compliance  = "required"
}
```

### 6. Use Least Privilege

```hcl
# ✅ Grant minimal permissions
managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]

# ❌ Avoid overly broad permissions
# managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
```

## Common Patterns

### Pattern 1: Cross-Account Role

```hcl
roles = {
  cross_account = {
    name = "CrossAccountRole"
    
    assume_role_policy = jsonencode({
      Statement = [{
        Action = "sts:AssumeRole"
        Principal = {
          AWS = "arn:aws:iam::OTHER_ACCOUNT:root"
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }]
    })
    
    managed_policy_arns = var.allowed_policies
  }
}
```

### Pattern 2: GitHub Actions Role

```hcl
oidc_providers = {
  github = {
    url            = "https://token.actions.githubusercontent.com"
    client_id_list = ["sts.amazonaws.com"]
  }
}

roles = {
  github_deploy = {
    name = "GitHubDeploy"
    
    assume_role_policy = jsonencode({
      Statement = [{
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:org/repo:*"
          }
        }
      }]
    })
  }
}
```

### Pattern 3: Organization-Wide Policy

```hcl
policies = {
  enforce_encryption = {
    name        = "EnforceEncryption"
    description = "Require encryption for all S3 and EBS"
    
    policy = jsonencode({
      Statement = [{
        Effect = "Deny"
        Action = ["s3:PutObject"]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }]
    })
  }
}
```

## Integration Examples

### With CI/CD (GitHub Actions)

```yaml
# .github/workflows/deploy.yml
name: Deploy
on: [push]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
          aws-region: us-east-1
      
      - name: Deploy
        run: terraform apply -auto-approve
```

### With AWS Organizations

```hcl
# In security account
roles = {
  org_admin = {
    name = "OrganizationAdministrator"
    
    assume_role_policy = jsonencode({
      Statement = [{
        Action = "sts:AssumeRole"
        Principal = {
          AWS = "arn:aws:iam::MASTER_ACCOUNT:root"
        }
      }]
    })
    
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/AdministratorAccess"
    ]
  }
}
```

### With SSO (SAML)

```hcl
saml_providers = {
  okta = {
    name                   = "OktaSSO"
    saml_metadata_document = file("${path.module}/okta-metadata.xml")
  }
}

roles = {
  sso_admin = {
    name = "SSOAdministrator"
    
    assume_role_policy = jsonencode({
      Statement = [{
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::ACCOUNT_ID:saml-provider/OktaSSO"
        }
        Action = "sts:AssumeRoleWithSAML"
        Condition = {
          StringEquals = {
            "SAML:aud" = "https://signin.aws.amazon.com/saml"
          }
        }
      }]
    })
    
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/AdministratorAccess"
    ]
  }
}
```

## Security

### External IDs

Always use external IDs for cross-account access:

```hcl
Condition = {
  StringEquals = {
    "sts:ExternalId" = "randomly-generated-unique-id"
  }
}
```

### Session Duration

Limit session duration:

```hcl
max_session_duration = 3600  # 1 hour for least privilege
```

### MFA for Sensitive Roles

```hcl
Condition = {
  Bool = {
    "aws:MultiFactorAuthPresent" = "true"
  }
}
```

### Permissions Boundaries

```hcl
roles = {
  developer = {
    permissions_boundary = "arn:aws:iam::aws:policy/PowerUserAccess"
    # Prevents privilege escalation
  }
}
```

## Troubleshooting

### AssumeRole Access Denied

```bash
# Check trust policy
aws iam get-role --role-name MyRole

# Test assume role
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/MyRole \
  --role-session-name test
```

### Policy Not Attached

```bash
# List attached policies
aws iam list-attached-role-policies --role-name MyRole

# List inline policies
aws iam list-role-policies --role-name MyRole
```

### OIDC Provider Issues

```bash
# Verify provider exists
aws iam list-open-id-connect-providers

# Get provider details
aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com
```

## References

- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AssumeRole Trust Policies](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user.html)
- [OIDC Providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [Architecture Decision: IAM](../../ARCHITECTURE_DECISION_IAM.md)

## Related Documentation

- [Architecture Decision on IAM](../../ARCHITECTURE_DECISION_IAM.md) - **READ THIS FIRST**
- [ECS Module](../ecs/README.md) - For ECS-specific IAM
- [EC2 Module](../ec2/README.md) - For EC2 instance profiles
- [Lambda Module](../lambda/README.md) - For Lambda execution roles
