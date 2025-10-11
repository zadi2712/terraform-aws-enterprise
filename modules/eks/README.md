# EKS Cluster Module

Comprehensive Amazon EKS (Elastic Kubernetes Service) cluster module with managed node groups and enterprise-ready add-ons.

## Features

### Core Components
- **EKS Control Plane** - Fully managed Kubernetes control plane
- **Managed Node Groups** - Auto-scaling worker nodes with customizable instance types
- **IRSA (IAM Roles for Service Accounts)** - Secure pod-level AWS permissions
- **Envelope Encryption** - KMS encryption for Kubernetes secrets
- **Control Plane Logging** - CloudWatch logs for API, audit, authenticator, controller manager, and scheduler

### Add-ons Included
- **VPC CNI** - Native VPC networking for pods
- **CoreDNS** - DNS service discovery
- **kube-proxy** - Network proxy
- **EBS CSI Driver** - Persistent storage with EBS volumes
- **Cluster Autoscaler** - Automatic node scaling based on pod requirements
- **Cert-Manager** - Automated TLS certificate management with Let's Encrypt
- **AWS Load Balancer Controller** - Provision ALB/NLB for Kubernetes services
- **NGINX Ingress Controller** - HTTP/HTTPS ingress management (via Helm)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       EKS Cluster                            │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Control Plane (Managed by AWS)            │ │
│  │  • API Server  • Controller Manager  • Scheduler       │ │
│  └────────────────────────────────────────────────────────┘ │
│                            │                                 │
│  ┌─────────────────────────┴────────────────────────────┐  │
│  │              Node Groups (Managed Workers)            │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐           │  │
│  │  │  Node 1  │  │  Node 2  │  │  Node 3  │           │  │
│  │  │  ┌────┐  │  │  ┌────┐  │  │  ┌────┐  │           │  │
│  │  │  │Pod │  │  │  │Pod │  │  │  │Pod │  │           │  │
│  │  │  └────┘  │  │  └────┘  │  │  └────┘  │           │  │
│  │  └──────────┘  └──────────┘  └──────────┘           │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                    Add-ons Layer                      │  │
│  │  • Cluster Autoscaler  • Cert-Manager                │  │
│  │  • AWS LB Controller   • NGINX Ingress               │  │
│  │  • EBS CSI Driver      • VPC CNI                     │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Example

```hcl
module "eks" {
  source = "../../../modules/eks"

  cluster_name    = "production-eks"
  cluster_version = "1.28"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  node_groups = {
    general = {
