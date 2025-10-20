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

The compute layer now includes comprehensive ECS support with IAM roles, security groups, and service discovery.

#### Basic ECS Cluster

Minimal ECS setup for development:

```hcl
enable_ecs = true
enable_container_insights = true

ecs_capacity_providers = ["FARGATE", "FARGATE_SPOT"]

ecs_default_capacity_provider_strategy = [
  {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
]

# Enable IAM roles
ecs_create_task_execution_role = true
ecs_create_task_role           = true

# Enable security group
ecs_create_security_group = true
ecs_task_container_port   = 8080
```

#### Production ECS Cluster

Production-ready configuration with all features:

```hcl
enable_ecs = true
enable_container_insights = true

# Capacity providers with balanced strategy
ecs_capacity_providers = ["FARGATE", "FARGATE_SPOT"]

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

# Network configuration
ecs_create_security_group = true
ecs_task_container_port   = 8080

# IAM roles for tasks
ecs_create_task_execution_role = true
ecs_create_task_role           = true

# Service discovery for microservices
ecs_enable_service_discovery    = true
ecs_service_discovery_namespace = "services.internal"

# Logging and debugging
ecs_enable_execute_command = false  # Disabled in prod for security
ecs_log_retention_days     = 30
```

#### ECS with Service Discovery

For microservices architectures:

```hcl
enable_ecs = true

# Enable service discovery
ecs_enable_service_discovery    = true
ecs_service_discovery_namespace = "myapp.local"

# Services can communicate via DNS: service-name.myapp.local
```

#### ECS Variables Reference

| Variable | Description | Default |
|----------|-------------|---------|
| `ecs_capacity_providers` | List of capacity providers | `["FARGATE", "FARGATE_SPOT"]` |
| `ecs_default_capacity_provider_strategy` | Capacity provider strategy | See defaults |
| `ecs_create_security_group` | Create security group for tasks | `true` |
| `ecs_task_container_port` | Container port | `8080` |
| `ecs_create_task_execution_role` | Create task execution role | `true` |
| `ecs_create_task_role` | Create task role | `true` |
| `ecs_enable_service_discovery` | Enable Cloud Map | `false` |
| `ecs_service_discovery_namespace` | Service discovery namespace | `"local"` |
| `ecs_enable_execute_command` | Enable ECS Exec | `false` |
| `ecs_log_retention_days` | Log retention days | `7` |

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
# Cluster
ecs_cluster_id                             # ECS cluster ID
ecs_cluster_name                           # ECS cluster name
ecs_cluster_arn                            # ECS cluster ARN

# IAM Roles
ecs_task_execution_role_arn                # Task execution role ARN
ecs_task_execution_role_name               # Task execution role name
ecs_task_role_arn                          # Task role ARN
ecs_task_role_name                         # Task role name

# Network
ecs_security_group_id                      # Tasks security group ID
ecs_security_group_arn                     # Tasks security group ARN

# Service Discovery
ecs_service_discovery_namespace_id         # Cloud Map namespace ID
ecs_service_discovery_namespace_arn        # Cloud Map namespace ARN
ecs_service_discovery_namespace_hosted_zone # Route53 hosted zone ID

# Logging
ecs_exec_command_log_group_name            # ECS Exec log group name
ecs_exec_command_log_group_arn             # ECS Exec log group ARN
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

1. **Verify cluster creation:**
   ```bash
   aws ecs describe-clusters --clusters myproject-dev-ecs
   ```

2. **Create task definitions:**
   ```bash
   # The compute layer provides IAM roles, use them:
   # - Task Execution Role: ecs_task_execution_role_arn
   # - Task Role: ecs_task_role_arn
   # - Security Group: ecs_security_group_id
   
   # Example task definition:
   cat > task-definition.json <<EOF
   {
     "family": "myapp",
     "networkMode": "awsvpc",
     "requiresCompatibilities": ["FARGATE"],
     "cpu": "256",
     "memory": "512",
     "executionRoleArn": "$(terraform output -raw ecs_task_execution_role_arn)",
     "taskRoleArn": "$(terraform output -raw ecs_task_role_arn)",
     "containerDefinitions": [{
       "name": "app",
       "image": "nginx:latest",
       "portMappings": [{
         "containerPort": 80,
         "protocol": "tcp"
       }],
       "logConfiguration": {
         "logDriver": "awslogs",
         "options": {
           "awslogs-group": "/ecs/myapp",
           "awslogs-region": "us-east-1",
           "awslogs-stream-prefix": "app"
         }
       }
     }]
   }
   EOF
   
   aws ecs register-task-definition --cli-input-json file://task-definition.json
   ```

3. **Create ECS services:**
   ```bash
   aws ecs create-service \
     --cluster myproject-dev-ecs \
     --service-name myapp \
     --task-definition myapp:1 \
     --desired-count 2 \
     --launch-type FARGATE \
     --network-configuration "awsvpcConfiguration={
       subnets=[subnet-xxx,subnet-yyy],
       securityGroups=[$(terraform output -raw ecs_security_group_id)],
       assignPublicIp=DISABLED
     }"
   ```

4. **Configure auto-scaling:**
   ```bash
   # Register scalable target
   aws application-autoscaling register-scalable-target \
     --service-namespace ecs \
     --resource-id service/myproject-dev-ecs/myapp \
     --scalable-dimension ecs:service:DesiredCount \
     --min-capacity 2 \
     --max-capacity 10
   
   # Create scaling policy
   aws application-autoscaling put-scaling-policy \
     --service-namespace ecs \
     --resource-id service/myproject-dev-ecs/myapp \
     --scalable-dimension ecs:service:DesiredCount \
     --policy-name cpu-scaling \
     --policy-type TargetTrackingScaling \
     --target-tracking-scaling-policy-configuration file://scaling-policy.json
   ```

5. **Use ECS Exec for debugging (if enabled):**
   ```bash
   # Get task ID
   TASK_ID=$(aws ecs list-tasks --cluster myproject-dev-ecs --service-name myapp --query 'taskArns[0]' --output text)
   
   # Connect to task
   aws ecs execute-command \
     --cluster myproject-dev-ecs \
     --task $TASK_ID \
     --container app \
     --interactive \
     --command "/bin/bash"
   ```

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
