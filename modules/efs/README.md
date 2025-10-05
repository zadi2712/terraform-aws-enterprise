# EFS File System Module

Amazon Elastic File System for shared storage.

## Features
- EFS file system
- Mount targets across AZs
- Backup policy
- Lifecycle management
- Encryption at rest
- Access points

## Usage

```hcl
module "shared_storage" {
  source = "../../../modules/efs"

  name           = "shared-data"
  encrypted      = true
  kms_key_id     = module.kms.key_id
  
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
  security_group_ids = [module.efs_sg.security_group_id]
  
  lifecycle_policy = {
    transition_to_ia = "AFTER_30_DAYS"
  }
  
  tags = {
    Environment = "production"
  }
}
```
