# EKS Cluster Module v2.0

Enterprise-grade Amazon EKS (Elastic Kubernetes Service) cluster module with modern features including EKS Pod Identity, Karpenter autoscaling, comprehensive monitoring, and managed add-ons.

## 🎯 Features

### Core Capabilities
- **EKS Control Plane** - Fully managed Kubernetes 1.31+ cluster
- **Managed Node Groups** - Auto-scaling EC2 worker nodes with customizable configurations
- **Fargate Profiles** - Serverless compute for Kubernetes pods
- **EKS Pod Identity** - Modern, simplified IAM authentication (replaces IRSA)
- **EKS Access Entries** - Native RBAC management via AWS API
- **Envelope Encryption** - KMS encryption for Kubernetes secrets at rest
- **Control Plane Logging** - Comprehensive CloudWatch logging

### Modern Autoscaling
- **Karpenter** - Advanced, intelligent node provisioning and scaling (recommended)
- **Cluster Autoscaler** - Traditional ASG-based autoscaling (legacy option)

### Managed Add-ons
- **VPC CNI** - Native AWS VPC networking for pods with ENI support
- **CoreDNS** - DNS service discovery for Kubernetes
- **kube-proxy** - Network proxy for Kubernetes services
- **EBS CSI Driver** - Persistent block storage with EBS volumes
- **EFS CSI Driver** - Persistent shared storage with EFS
- **CloudWatch Observability** - Integrated metrics, logs, and traces
- **GuardDuty Agent** - Runtime threat detection for EKS workloads
- **Pod Identity Agent** - Required for EKS Pod Identity feature

### Additional Controllers (IRSA/Pod Identity Supported)
- **AWS Load Balancer Controller** - Provision ALB/NLB for Kubernetes Ingress
- **External DNS** - Automatic Route53 DNS record management
- **Cluster Autoscaler** - Traditional ASG-based pod autoscaling (alternative to Karpenter)

## 📋 Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.5.0
- AWS Provider >= 5.70.0
- VPC with private subnets (and optionally public subnets)
- KMS key for secrets encryption (optional but recommended)

## 🏗️ Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                      EKS Cluster (1.31)                        │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         Control Plane (Managed by AWS)                   │  │
│  │  • API Server (HA)     • etcd (HA)                       │  │
│  │  • Controller Manager  • Scheduler                       │  │
│  │  • Cloud Controller    • Audit Logging                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│  ┌───────────────────────────┴─────────────────────────────┐  │
│  │                  Compute Options                         │  │
│  │  ┌──────────────┐    ┌──────────────┐    ┌──────────┐  │  │
│  │  │ Managed Node │    │   Fargate    │    │ Karpenter│  │  │
│  │  │    Groups    │    │   Profiles   │    │   Nodes  │  │  │
│  │  │              │    │              │    │          │  │  │
│  │  │ • On-Demand  │    │ • Serverless │    │ • Spot   │  │  │
│  │  │ • Spot       │    │ • No Mgmt    │    │ • Auto   │  │  │
│  │  └──────────────┘    └──────────────┘    └──────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                 Add-ons & Controllers                     │  │
│  │                                                           │  │
│  │  Storage:          Networking:        Observability:     │  │
│  │  • EBS CSI         • VPC CNI          • CloudWatch       │  │
│  │  • EFS CSI         • CoreDNS          • Container        │  │
│  │                    • kube-proxy         Insights         │  │
│  │  Ingress/LB:       Autoscaling:       Security:          │  │
│  │  • AWS LB Ctrl     • Karpenter        • GuardDuty        │  │
│  │  • External DNS    • Cluster AS       • Pod Identity     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Identity & Access Management                 │  │
│  │  • EKS Pod Identity (Modern)                             │  │
│  │  • IRSA/OIDC (Legacy, still supported)                   │  │
│  │  • EKS Access Entries (Native RBAC)                      │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

## 🚀 Usage Examples

### Basic Production Cluster

```hcl
module "eks" {
  source = "../../../modules/eks"

  cluster_name    = "production-eks"
  cluster_version = "1.31"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # Network configuration
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = ["203.0.113.0/24"] # Your office/VPN CIDR
  
  # Enable modern features
  enable_pod_identity = true
  authentication_mode = "API_AND_CONFIG_MAP"
  
  # Encryption
  kms_key_arn = module.kms.key_arn
  
  # Node groups
  node_groups = {
    general = {
      instance_types = ["t3.large"]
      desired_size   = 3
      min_size       = 2
      max_size       = 10
      disk_size      = 100
      
      labels = {
        role = "general"
      }
    }
    
    spot = {
      instance_types = ["t3.large", "t3a.large"]
      capacity_type  = "SPOT"
      desired_size   = 2
      min_size       = 0
      max_size       = 10
      
      labels = {
        role = "spot"
      }
      
      taints = [{
        key    = "spot"
        value  = "true"
        effect = "NoSchedule"
      }]
    }
  }
  
  # Enable Karpenter for advanced autoscaling
  enable_karpenter = true
  
  # Add-ons
  enable_ebs_csi_driver          = true
  enable_efs_csi_driver          = true
  enable_cloudwatch_observability = true
  enable_guardduty_agent         = true
  
  # Controllers
  enable_aws_load_balancer_controller = true
  enable_external_dns                 = true
  external_dns_route53_zone_arns      = [
    "arn:aws:route53:::hostedzone/Z1234567890ABC"
  ]
  
  tags = {
    Environment = "production"
    Team        = "platform"
  }
}
```

### Cluster with Fargate Profiles

```hcl
module "eks_fargate" {
  source = "../../../modules/eks"

  cluster_name    = "fargate-eks"
  cluster_version = "1.31"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # Fargate profiles for serverless workloads
  fargate_profiles = {
    kube_system = {
      selectors = [
        {
          namespace = "kube-system"
          labels = {
            k8s-app = "kube-dns"
          }
        }
      ]
    }
    
    applications = {
      selectors = [
        {
          namespace = "apps"
        },
        {
          namespace = "staging"
        }
      ]
    }
  }
  
  # Minimal node group for system pods
  node_groups = {
    system = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 2
      max_size       = 4
      
      labels = {
        role = "system"
      }
      
      taints = [{
        key    = "CriticalAddonsOnly"
        value  = "true"
        effect = "NoSchedule"
      }]
    }
  }
  
  enable_pod_identity = true
  enable_karpenter    = false
}
```

### Multi-Environment Access Control

```hcl
module "eks_with_rbac" {
  source = "../../../modules/eks"

  cluster_name    = "platform-eks"
  cluster_version = "1.31"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # Modern authentication
  authentication_mode = "API"
  bootstrap_cluster_creator_admin_permissions = true
  
  # EKS Access Entries for team access
  access_entries = {
    platform_team = {
      principal_arn = "arn:aws:iam::123456789012:role/PlatformTeam"
      type          = "STANDARD"
      
      policy_associations = [
        {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope_type = "cluster"
        }
      ]
    }
    
    dev_team = {
      principal_arn = "arn:aws:iam::123456789012:role/DevTeam"
      type          = "STANDARD"
      
      policy_associations = [
        {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
          access_scope_type = "namespace"
          namespaces = ["development", "staging"]
        }
      ]
    }
    
    readonly_auditors = {
      principal_arn = "arn:aws:iam::123456789012:role/Auditors"
      type          = "STANDARD"
      
      policy_associations = [
        {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope_type = "cluster"
        }
      ]
    }
  }
  
  node_groups = {
    general = {
      instance_types = ["t3.large"]
      desired_size   = 3
      min_size       = 2
      max_size       = 10
    }
  }
  
  enable_pod_identity = true
  enable_karpenter    = true
}
```

## 📊 Complete Configuration Reference

### Node Group Configuration

```hcl
node_groups = {
  example = {
    # Required
    instance_types = ["t3.large", "t3a.large"]  # List of instance types
    
    # Scaling (all optional)
    desired_size = 3
    min_size     = 1
    max_size     = 10
    max_unavailable_percentage = 33  # For rolling updates
    
    # Capacity
    capacity_type = "ON_DEMAND"  # or "SPOT"
    disk_size     = 50           # GB
    ami_type      = "AL2_x86_64" # or "AL2_ARM_64", "BOTTLEROCKET_x86_64", etc.
    
    # Kubernetes
    version = "1.31"  # Defaults to cluster version
    labels = {
      role        = "application"
      environment = "production"
    }
    taints = [
      {
        key    = "dedicated"
        value  = "application"
        effect = "NoSchedule"
      }
    ]
    
    # Advanced (optional)
    subnet_ids = ["subnet-xxx"]  # Override cluster subnets
    launch_template_id = "lt-xxx"
    launch_template_version = "$Latest"
    
    # Remote access (optional)
    enable_remote_access = true
    ec2_ssh_key = "my-key"
    remote_access_sg_ids = ["sg-xxx"]
    
    tags = {
      Team = "platform"
    }
  }
}
```

### Fargate Profile Configuration

```hcl
fargate_profiles = {
  example = {
    subnet_ids = ["subnet-xxx", "subnet-yyy"]  # Private subnets
    
    selectors = [
      {
        namespace = "apps"
        labels = {
          compute = "fargate"
        }
      },
      {
        namespace = "batch-jobs"
      }
    ]
    
    tags = {
      Profile = "example"
    }
  }
}
```

### Access Entries Configuration

```hcl
access_entries = {
  admin_role = {
    principal_arn = "arn:aws:iam::ACCOUNT:role/AdminRole"
    type          = "STANDARD"  # or "FARGATE_LINUX", "EC2_LINUX", "EC2_WINDOWS"
    user_name     = "admin-role"  # Optional
    
    policy_associations = [
      {
        policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope_type = "cluster"  # or "namespace"
        namespaces        = []         # Required if access_scope_type = "namespace"
      }
    ]
  }
}
```

## 🔐 Security Best Practices

### 1. Network Security
- Keep API endpoint private unless necessary
- Use Security Groups to restrict access
- Enable VPC Flow Logs
- Use private subnets for nodes

### 2. Encryption
- Enable envelope encryption with KMS
- Rotate KMS keys regularly
- Use encrypted EBS volumes

### 3. Authentication & Authorization
- Use EKS Pod Identity (modern) instead of IRSA
- Implement EKS Access Entries for IAM-to-Kubernetes mapping
- Enable audit logging
- Use least-privilege IAM policies

### 4. Monitoring & Compliance
- Enable all control plane logs
- Use CloudWatch Container Insights
- Enable GuardDuty for runtime protection
- Implement AWS Config rules

### 5. Updates & Patching
- Keep cluster version up-to-date
- Update managed add-ons regularly
- Use managed node groups for easier updates
- Test updates in non-production first

## 🔄 Migration Guide

### IRSA to Pod Identity

Pod Identity is the modern, simplified way to grant AWS permissions to Kubernetes pods:

**Old Way (IRSA):**
```hcl
enable_pod_identity = false  # Uses OIDC provider
```

**New Way (Pod Identity):**
```hcl
enable_pod_identity = true   # Uses EKS Pod Identity
```

Benefits:
- No OIDC provider to manage
- Simpler trust policies
- Better scaling (no OIDC token limits)
- Faster pod startup
- Easier to audit

### Cluster Autoscaler to Karpenter

Karpenter provides more intelligent, faster, and cost-effective autoscaling:

**Old Way:**
```hcl
enable_cluster_autoscaler = true
enable_karpenter = false
```

**New Way:**
```hcl
enable_cluster_autoscaler = false
enable_karpenter = true
```

Benefits:
- Sub-minute node provisioning
- Better bin-packing
- Mixed instance types
- Spot and on-demand mixed
- Pod-level scheduling awareness

## 📦 Outputs

| Output | Description |
|--------|-------------|
| `cluster_id` | Cluster name/ID |
| `cluster_endpoint` | Kubernetes API endpoint |
| `cluster_certificate_authority_data` | CA certificate (base64) |
| `cluster_security_group_id` | Cluster security group |
| `oidc_provider_arn` | OIDC provider ARN (if IRSA enabled) |
| `pod_identity_enabled` | Whether Pod Identity is enabled |
| `node_groups` | Node group details |
| `fargate_profiles` | Fargate profile details |
| `karpenter_iam_role_arn` | Karpenter IAM role ARN |
| `kubeconfig_command` | Command to update kubeconfig |
| `cluster_info` | Comprehensive cluster information |

## 🛠️ Post-Deployment Steps

### 1. Update kubeconfig

```bash
aws eks update-kubeconfig --region <region> --name <cluster-name>
```

### 2. Verify cluster access

```bash
kubectl get nodes
kubectl get pods -A
```

### 3. Install Karpenter (if enabled)

```bash
helm repo add karpenter https://charts.karpenter.sh
helm upgrade --install karpenter karpenter/karpenter \
  --namespace karpenter --create-namespace \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<karpenter-role-arn> \
  --set settings.clusterName=<cluster-name> \
  --set settings.clusterEndpoint=<cluster-endpoint>
```

### 4. Install AWS Load Balancer Controller (if enabled)

```bash
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<cluster-name> \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

## 📚 Additional Resources

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [EKS Pod Identity Documentation](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [Karpenter Documentation](https://karpenter.sh/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

## 🐛 Troubleshooting

### Nodes not joining cluster

1. Check security groups allow nodes to reach control plane
2. Verify IAM role has required policies
3. Check node group logs in CloudWatch
4. Verify subnets have available IPs

### Pods can't assume IAM roles

1. If using Pod Identity: Ensure addon is installed and association exists
2. If using IRSA: Verify OIDC provider is configured correctly
3. Check service account annotations
4. Verify trust policy allows pod to assume role

### Karpenter not provisioning nodes

1. Check Karpenter logs: `kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter`
2. Verify IAM role has EC2 permissions
3. Check NodePool and EC2NodeClass configurations
4. Ensure subnet tags include `karpenter.sh/discovery: <cluster-name>`

## 📝 Version History

- **v2.0** - Added EKS Pod Identity, Karpenter, EKS 1.31 support, Access Entries, enhanced monitoring
- **v1.0** - Initial release with IRSA, Cluster Autoscaler, basic add-ons

## 📄 License

Copyright © 2025. All rights reserved.
