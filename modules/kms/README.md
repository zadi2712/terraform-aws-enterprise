# KMS Key Module

AWS Key Management Service encryption keys.

## Features
- KMS key creation
- Key rotation
- Key policies
- Aliases
- Multi-region keys support

## Usage

```hcl
module "encryption_key" {
  source = "../../../modules/kms"

  description             = "Encryption key for RDS"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  key_administrators = [
    "arn:aws:iam::123456789:role/admin-role"
  ]
  
  key_users = [
    "arn:aws:iam::123456789:role/application-role"
  ]
  
  tags = {
    Environment = "production"
  }
}
```
