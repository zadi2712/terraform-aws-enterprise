# EKS Quick Reference Guide

## Quick Commands

### Cluster Access

```bash
# Update kubeconfig
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Verify connection
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Get cluster information
aws eks describe-cluster --name <cluster-name> --region <region>
```

### Terraform Operations

```bash
# Initialize
cd layers/compute/environments/<env>
terraform init -backend-config=backend.conf

# Plan
terraform plan -out=tfplan

# Apply
terraform apply tfplan

# Get outputs
terraform output
terraform output -json > outputs.json

# Destroy
terraform destroy
```

### Karpenter Commands

```bash
# Check Karpenter status
kubectl get pods -n karpenter
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f

# List NodePools
kubectl get nodepools

# List EC2NodeClasses
kubectl get ec2nodeclasses

# Trigger scaling test
kubectl scale deployment inflate --replicas=10
```

### AWS Load Balancer Controller

```bash
# Check controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# List Ingresses
kubectl get ingress -A

# Describe Ingress
kubectl describe ingress <name> -n <namespace>

# Check TargetGroups
kubectl get targetgroupbindings -A
```

### Monitoring

```bash
# Container Insights
kubectl get pods -n amazon-cloudwatch

# Check logs
kubectl logs -n kube-system <pod-name>

# View events
kubectl get events -A --sort-by='.lastTimestamp'
```

### Debugging

```bash
# Node status
kubectl describe node <node-name>

# Pod logs
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous

# Pod events
kubectl describe pod <pod-name> -n <namespace>

# Execute into pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Port forward
kubectl port-forward <pod-name> -n <namespace> 8080:80
```

## Common Configuration Patterns

### Cost-Optimized (Development)

```hcl
enable_eks = true
eks_cluster_version = "1.31"
eks_enable_pod_identity = true

eks_node_groups = {
  spot = {
    instance_types = ["t3.medium", "t3a.medium"]
    capacity_type  = "SPOT"
    desired_size   = 2
    min_size       = 1
    max_size       = 5
  }
}

eks_enable_karpenter = true
eks_enable_cloudwatch_observability = false
```

### High-Availability (Production)

```hcl
enable_eks = true
eks_cluster_version = "1.31"
eks_enable_pod_identity = true

eks_node_groups = {
  on_demand = {
    instance_types = ["t3.large"]
    capacity_type  = "ON_DEMAND"
    desired_size   = 6
    min_size       = 3
    max_size       = 20
  }
  spot = {
    instance_types = ["t3.large", "t3a.large"]
    capacity_type  = "SPOT"
    desired_size   = 3
    min_size       = 0
    max_size       = 15
  }
}

eks_enable_karpenter = true
eks_enable_cloudwatch_observability = true
eks_enable_guardduty_agent = true
```

### Fargate-Focused

```hcl
enable_eks = true
eks_cluster_version = "1.31"

eks_node_groups = {
  system = {
    instance_types = ["t3.medium"]
    desired_size   = 2
    min_size       = 2
    max_size       = 4
  }
}

eks_fargate_profiles = {
  apps = {
    selectors = [
      { namespace = "production" },
      { namespace = "staging" }
    ]
  }
}
```

## Troubleshooting Quick Fixes

### Nodes Not Joining

```bash
# Check node IAM role
aws iam get-role --role-name <node-role-name>

# Verify security groups
aws eks describe-cluster --name <cluster> --query 'cluster.resourcesVpcConfig'

# Check CloudWatch logs
aws logs tail /aws/eks/<cluster>/cluster --follow
```

### Pods Pending

```bash
# Check why pending
kubectl describe pod <pod-name> -n <namespace>

# Check node resources
kubectl top nodes

# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter
```

### Ingress Not Working

```bash
# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Verify Ingress
kubectl describe ingress <name> -n <namespace>

# Check service
kubectl describe svc <service-name> -n <namespace>
```

## Best Practices Checklist

### Security
- [ ] Private API endpoint enabled
- [ ] Public access restricted to known CIDRs
- [ ] Pod Identity enabled
- [ ] KMS encryption enabled
- [ ] GuardDuty agent enabled (prod)
- [ ] Network policies configured
- [ ] Pod security standards enforced

### High Availability
- [ ] Multiple AZs configured
- [ ] Multiple node groups
- [ ] Proper resource requests/limits
- [ ] PodDisruptionBudgets defined
- [ ] Health checks configured

### Cost Optimization
- [ ] Karpenter enabled
- [ ] Spot instances for appropriate workloads
- [ ] Right-sized node groups
- [ ] Cluster autoscaling enabled
- [ ] Resource quotas defined

### Monitoring
- [ ] CloudWatch Observability enabled
- [ ] Container Insights enabled
- [ ] Log retention configured
- [ ] Alerts configured
- [ ] Dashboards created

## Important Notes

### Pod Identity vs IRSA

**Use Pod Identity (Default):**
```hcl
eks_enable_pod_identity = true
```

**Legacy IRSA:**
```hcl
eks_enable_pod_identity = false
```

### Karpenter vs Cluster Autoscaler

**Use Karpenter (Recommended):**
```hcl
eks_enable_karpenter = true
eks_enable_cluster_autoscaler = false
```

**Legacy Cluster Autoscaler:**
```hcl
eks_enable_karpenter = false
eks_enable_cluster_autoscaler = true
```

## Resource Limits

### Default Quotas
- Max nodes per cluster: 450
- Max pods per node: 110 (depends on instance type)
- Max Fargate pods: 100 per profile

### Service Quotas to Monitor
- VPC
- Elastic IPs
- Security Groups
- IAM Roles

## Useful Links

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Karpenter Docs](https://karpenter.sh/)
- [AWS LB Controller Docs](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [Kubernetes Docs](https://kubernetes.io/docs/home/)

## Support

For issues or questions:
1. Check logs: `kubectl logs <pod> -n <namespace>`
2. Check events: `kubectl get events -A`
3. Review documentation
4. Contact platform team
