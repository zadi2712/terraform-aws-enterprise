# IAM Module

IAM roles, policies, and groups management.

## Features
- IAM Roles with trust policies
- IAM Policies (managed and inline)
- IAM Groups
- IAM Users (not recommended for applications)
- Policy attachments

## Usage

```hcl
module "app_role" {
  source = "../../../modules/iam"

  role_name = "application-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]
  
  tags = {
    Environment = "production"
  }
}
```
