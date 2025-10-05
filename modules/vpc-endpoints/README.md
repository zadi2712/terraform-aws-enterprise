# VPC Endpoints Module

Interface and Gateway VPC endpoints for AWS services.

## Features
- Interface Endpoints (PrivateLink)
- Gateway Endpoints (S3, DynamoDB)
- Security group management
- DNS resolution
- Multiple services support

## Usage

```hcl
module "vpc_endpoints" {
  source = "../../../modules/vpc-endpoints"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  endpoints = {
    ec2 = {
      service             = "ec2"
      private_dns_enabled = true
    }
    s3 = {
      service      = "s3"
      service_type = "Gateway"
    }
  }
  
  tags = {
    Environment = "production"
  }
}
```
