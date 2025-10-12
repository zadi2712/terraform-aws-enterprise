# Compute Layer

The compute layer manages container orchestration platforms (EKS, ECS) and serverless compute (Lambda) for the enterprise infrastructure.

## Overview

This layer provisions and manages:
- **Amazon EKS** - Kubernetes clusters for containerized applications
- **Amazon ECS** - Container service for Docker workloads
- **AWS Lambda** - Serverless compute
- **Application Load Balancers** - Shared load balancing infrastructure

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       Compute Layer                              │
│                                                                   │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐ │
│  │       EKS        │  │       ECS        │  │    Lambda     │ │
│  │  • Kubernetes    │  │  • Fargate       │  │  • Functions  │ │
│  │  • Node Groups   │  │  • EC2           │  │  • VPC Config │ │
│  │  • Fargate       │  │  • Spot          │  │               │ │
│  │  • Karpenter     │  │                  │  │               │ │
│  └──────────────────┘  └──────────────────┘  └───────────────┘ │
│           │                     │                     │          │
│           └─────────────────────┴─────────────────────┘          │
│                              │                                    │
│                    ┌─────────▼──────────┐                       │
│                    │   Shared ALB SG     │                       │
│                    └─────────────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┴──────────────┐
                │                            │
        ┌───────▼────────┐          ┌───────▼────────┐
        │   Networking   │          │    Security    │
        │     Layer      │          │      Layer     │
        └────────────────┘          └────────────────┘
```

## Directory Structure

```
layers/compute/
├── main.tf                      # Main Terraform configuration
├── variables.tf                 # Variable definitions
├── outputs.tf                   # Output definitions
├── versions.tf                  # Provider version constraints
├── README.md                    # This file
└── environments/
    ├── dev/
    │   ├── backend.conf         # Backend configuration
    │   └── terraform.tfvars     # Environment variables
    ├── qa/
    │   ├── backend.conf
    │   └── terraform.tfvars
    ├── uat/
    │   ├── backend.conf
    │   └── terraform.tfvars
    └── prod/
        ├── backend.conf
        └── terraform.tfvars
```

## Prerequisites

### Required Layers

The compute layer depends on:
1. **Networking Layer** - Must be deployed first
   - VPC and subnets
   - NAT Gateways
   - Route tables

2. **Security Layer** - Should be deployed first
   - KMS keys for encryption
   - Security groups
   - IAM policies

### Tools Required

- Terraform >= 1.5.0
- AWS CLI v2
- kubectl (for EKS)
- Helm v3 (for EKS add-ons)

## Quick Start

### 1. Deploy Networking Layer

```bash
cd layers/networking/environments/dev
terraform init -backend-config=backend.conf
terraform apply
```

### 2. Deploy Security Layer

```bash
cd layers/security/environments/dev
terraform init -backend-config=backend.conf
terraform apply
```

### 3. Configure Compute Layer

```bash
cd layers/compute/environments/dev
```

Edit `terraform.tfvars`:

```hcl
# Enable EKS
enable_eks = true
eks_cluster_version = "1.31"

# Configure node groups
eks_node_groups = {
  general = {
    desired_size   = 3
    min_size       = 2
    max_size       = 10
    instance_types = ["t3.large"]
  }
}

# Enable add-ons
eks_enable_karpenter = true
eks_enable_aws_load_balancer_controller = true
```

### 4. Deploy Compute Layer

```bash
terraform init -backend-config=backend.conf
terraform plan
terraform apply
```

### 5. Configure kubectl

```bash
aws eks update-kubeconfig --name myproject-dev-eks --region us-east-1
kubectl get nodes
```

## Configuration Guide

### EKS Configuration

#### Basic EKS Cluster

Minimal configuration for development:

```hcl
enable_eks = true
eks_cluster_version = "1.31"

eks_node_groups = {
  general = {
    desired_size   = 2
    min_size       = 1
    max_size       = 5
    instance_types = ["t3.medium"]
  }
}
```

#### Production EKS Cluster

Production-ready configuration:

```hcl
enable_eks = true
eks_cluster_version = "1.31"

# Security
eks_endpoint_private_access = true
eks_endpoint_public_access  = false

# Modern features
eks_enable_pod_identity  = true
eks_authentication_mode  = "API_AND_CONFIG_MAP"

# Multiple node groups
eks_node_groups = {
  critical = {
    desired_size   = 3
    min_size       = 3
    max_size       = 10
    instance_types = ["m5.xlarge"]
    capacity_type  = "ON_DEMAND"
    labels = {
      workload = "critical"
    }
    taints = [
      {
        key    = "critical"
        value  = "true"
        effect = "NoSchedule"
      }
    ]
  }
  
  general = {
    desired_size   = 5
    min_size       = 3
    max_size       = 20
    instance_types = ["m5.large"]
  }
  
  spot = {
    desired_size   = 3
    min_size       = 0
    max_size       = 20
    instance_types = ["m5.large", "m5a.large"]
    capacity_type  = "SPOT"
  }
}

# Fargate for specific workloads
eks_fargate_profiles = {
  kube-system = {
    selectors = [
      {
        namespace = "kube-system"
        labels = {
          k8s-app = "kube-dns"
        }
      }
    ]
  }
}

# Autoscaling
eks_enable_karpenter = true

# Full observability
eks_enable_ebs_csi_driver = true
eks_enable_efs_csi_driver = true
eks_enable_cloudwatch_observability = true
eks_enable_guardduty_agent = true

# Application controllers
eks_enable_aws_load_balancer_controller = true
eks_enable_cert_manager = true

# Comprehensive logging
eks_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
eks_log_retention_days = 90
```

### ECS Configuration

#### Basic ECS Cluster

```hcl
enable_ecs = true
enable_container_insights = true

ecs_capacity_providers = ["FARGATE", "FARGATE_SPOT"]
```

#### Production ECS Cluster

```hcl
enable_ecs = true
enable_container_insights = true

ecs_capacity_providers = ["FARGATE", "FARGATE_SPOT", "EC2"]

ecs_default_capacity_provider_strategy = [
  {
    capacity_provider = "FARGATE"
    weight            = 2
    base              = 2
  },
  {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
    base              = 0
  }
]
```

### Lambda Configuration

```hcl
enable_lambda = true
lambda_vpc_config_enabled = true
```

## Environment-Specific Configurations

### Development

- Smaller instance types (t3.medium)
- Lower node counts (2-5 nodes)
- Public API endpoint allowed
- Minimal logging (7 days retention)
- Cluster Autoscaler (simpler than Karpenter)

### Production

- Larger instance types (m5.large, m5.xlarge)
- Higher node counts (5-20 nodes)
- Private API endpoint only
- Comprehensive logging (90 days retention)
- Karpenter autoscaling
- GuardDuty runtime monitoring
- Multi-AZ node groups

## Outputs

Key outputs from the compute layer:

### EKS Outputs

```hcl
eks_cluster_name                     # Cluster name
eks_cluster_endpoint                 # API endpoint
eks_cluster_certificate_authority_data  # CA cert (sensitive)
eks_oidc_provider_arn                # OIDC provider ARN
eks_node_iam_role_arn                # Node IAM role
eks_karpenter_iam_role_arn           # Karpenter IAM role
eks_kubeconfig_command               # kubectl config command
```

### ECS Outputs

```hcl
ecs_cluster_id     # ECS cluster ID
ecs_cluster_name   # ECS cluster name
ecs_cluster_arn    # ECS cluster ARN
```

### Lambda Outputs

```hcl
lambda_execution_role_arn   # Lambda execution role
```

## Post-Deployment Steps

### For EKS

1. **Configure kubectl:**
   ```bash
   aws eks update-kubeconfig --name myproject-dev-eks --region us-east-1
   ```

2. **Install Karpenter** (if enabled):
   ```bash
   # See EKS_DEPLOYMENT_GUIDE.md for detailed instructions
   helm install karpenter karpenter/karpenter ...
   ```

3. **Install AWS Load Balancer Controller:**
   ```bash
   helm install aws-load-balancer-controller eks/aws-load-balancer-controller ...
   ```

4. **Install Cert-Manager:**
   ```bash
   helm install cert-manager jetstack/cert-manager ...
   ```

5. **Deploy applications:**
   ```bash
   kubectl apply -f your-app.yaml
   ```

### For ECS

1. **Create task definitions**
2. **Create services**
3. **Configure service discovery**
4. **Set up auto-scaling**

## Maintenance

### Upgrading EKS

1. Update `eks_cluster_version` in tfvars
2. Plan and apply:
   ```bash
   terraform plan
   terraform apply
   ```
3. Update node groups:
   - Create new node groups with new version
   - Drain old nodes
   - Delete old node groups

### Scaling

#### Manual Scaling

```bash
# Update node group desired size
terraform apply -var="eks_node_groups={...}"
```

#### Autoscaling

- **Karpenter**: Automatic based on pod requirements
- **Cluster Autoscaler**: Automatic based on node group ASGs

### Monitoring

View metrics in:
- AWS Console > EKS/ECS
- CloudWatch Container Insights
- kubectl commands
- Prometheus/Grafana (if deployed)

## Troubleshooting

### EKS Issues

**Nodes not joining cluster:**
```bash
# Check node group status
aws eks describe-nodegroup --cluster-name <name> --nodegroup-name <ng>

# Check CloudWatch logs
aws logs tail /aws/eks/<cluster-name>/cluster
```

**Pods pending:**
```bash
# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check autoscaler
kubectl logs -n kube-system deployment/cluster-autoscaler
# OR
kubectl logs -n karpenter deployment/karpenter
```

### ECS Issues

**Tasks not starting:**
```bash
# Check service events
aws ecs describe-services --cluster <cluster> --services <service>

# Check task logs
aws logs tail /ecs/<cluster>/<task-definition>
```

## Security Best Practices

1. **Network Isolation**
   - Use private subnets for nodes
   - Disable public API endpoint in production
   - Implement network policies

2. **Authentication**
   - Use Pod Identity for service accounts
   - Implement RBAC properly
   - Use EKS Access Entries

3. **Encryption**
   - Enable envelope encryption for secrets
   - Use encrypted EBS volumes
   - Enable CloudWatch log encryption

4. **Monitoring**
   - Enable GuardDuty runtime monitoring
   - Enable CloudWatch Container Insights
   - Implement comprehensive logging

## Cost Optimization

1. **Use Spot Instances**
   - Configure spot node groups
   - Use Karpenter for optimal spot usage

2. **Right-size Resources**
   - Monitor actual usage
   - Adjust instance types and counts
   - Use Fargate for variable workloads

3. **Autoscaling**
   - Implement HPA for pods
   - Use Karpenter/Cluster Autoscaler for nodes
   - Set appropriate min/max values

4. **Reserved Instances**
   - Purchase RIs for baseline capacity
   - Use Savings Plans

## Related Documentation

- [EKS Deployment Guide](../docs/EKS_DEPLOYMENT_GUIDE.md)
- [EKS Module README](../../modules/eks/README.md)
- [Architecture Documentation](../docs/ARCHITECTURE.md)
- [Security Best Practices](../docs/SECURITY.md)

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review module documentation
3. Check CloudWatch logs
4. Review AWS service health

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.
