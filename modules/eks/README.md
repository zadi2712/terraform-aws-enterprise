# EKS Cluster Module

Amazon EKS (Elastic Kubernetes Service) cluster with managed node groups.

## Features
- EKS Control Plane
- Managed Node Groups
- IRSA (IAM Roles for Service Accounts)
- Cluster autoscaling
- Add-ons support (VPC CNI, CoreDNS, kube-proxy)

## Usage

```hcl
module "eks" {
  source = "../../../modules/eks"

  cluster_name    = "production-eks"
  cluster_version = "1.28"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  node_groups = {
    general = {
      desired_size   = 3
      min_size       = 2
      max_size       = 10
      instance_types = ["t3.large"]
    }
  }
  
  tags = {
    Environment = "production"
  }
}
```
