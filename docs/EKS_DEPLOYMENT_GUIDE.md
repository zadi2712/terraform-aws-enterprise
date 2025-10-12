# EKS Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying an enterprise-grade Amazon EKS cluster using our updated Terraform modules with modern features including EKS Pod Identity, Karpenter, and comprehensive monitoring.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Deployment Steps](#deployment-steps)
4. [Post-Deployment Configuration](#post-deployment-configuration)
5. [Karpenter Setup](#karpenter-setup)
6. [AWS Load Balancer Controller Setup](#aws-load-balancer-controller-setup)
7. [External DNS Setup](#external-dns-setup)
8. [Monitoring and Observability](#monitoring-and-observability)
9. [Security Hardening](#security-hardening)
10. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

```bash
# Terraform >= 1.5.0
terraform version

# AWS CLI >= 2.13.0
aws --version

# kubectl >= 1.28
kubectl version --client

# Helm >= 3.12.0
helm version
```

### AWS Permissions

Your AWS credentials need the following permissions:
- EC2 full access
- EKS full access
- IAM full access (for role creation)
- KMS access (for encryption)
- CloudWatch Logs access
- VPC access
- Route53 access (if using External DNS)

### Network Prerequisites

Ensure you have:
- VPC with private and public subnets across multiple AZs
- NAT Gateways or NAT Instances in public subnets
- Security layer deployed (KMS keys)
- DNS zones (if using External DNS)

## Quick Start

### 1. Initialize and Deploy Networking Layer

```bash
cd layers/networking/environments/dev
terraform init -backend-config=backend.conf
terraform plan
terraform apply
```

### 2. Deploy Security Layer

```bash
cd ../../security/environments/dev
terraform init -backend-config=backend.conf
terraform plan
terraform apply
```

### 3. Deploy Compute Layer with EKS

```bash
cd ../../compute/environments/dev
terraform init -backend-config=backend.conf
terraform plan
terraform apply
```

## Deployment Steps

### Step 1: Configure Environment Variables

Edit `layers/compute/environments/<env>/terraform.tfvars`:

```hcl
# Basic configuration
aws_region   = "us-east-1"
environment  = "dev"
project_name = "mycompany"

# Enable EKS
enable_eks = true

# EKS version
eks_cluster_version = "1.31"

# Modern features
eks_enable_pod_identity = true
eks_authentication_mode = "API_AND_CONFIG_MAP"

# Node groups
eks_node_groups = {
  general = {
    instance_types = ["t3.large"]
    desired_size   = 3
    min_size       = 2
    max_size       = 10
    disk_size      = 100
  }
}

# Enable Karpenter
eks_enable_karpenter = true

# Enable monitoring
eks_enable_cloudwatch_observability = true
```

### Step 2: Review and Apply

```bash
# Review the plan
terraform plan -out=tfplan

# Apply the changes
terraform apply tfplan

# Save outputs for later use
terraform output -json > outputs.json
```

### Step 3: Update kubeconfig

```bash
# Get the kubeconfig command from outputs
terraform output eks_kubeconfig_command

# Execute it
aws eks update-kubeconfig --region us-east-1 --name mycompany-dev-eks

# Verify connectivity
kubectl get nodes
kubectl get pods -A
```

## Post-Deployment Configuration

### Verify Cluster Status

```bash
# Check cluster status
kubectl cluster-info

# Check nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Check add-ons
aws eks list-addons --cluster-name mycompany-dev-eks --region us-east-1
```

### Verify Pod Identity (if enabled)

```bash
# Check Pod Identity Agent
kubectl get pods -n kube-system -l app.kubernetes.io/name=eks-pod-identity-agent

# Check Pod Identity associations
aws eks list-pod-identity-associations \
  --cluster-name mycompany-dev-eks \
  --region us-east-1
```

## Karpenter Setup

Karpenter is a modern, intelligent node autoscaler that provisions the right compute resources for your pods.

### Step 1: Install Karpenter

```bash
# Get IAM role ARN
export KARPENTER_IAM_ROLE_ARN=$(terraform output -json | jq -r '.eks_karpenter_iam_role_arn.value')
export CLUSTER_NAME=$(terraform output -json | jq -r '.eks_cluster_name.value')
export CLUSTER_ENDPOINT=$(terraform output -json | jq -r '.eks_cluster_endpoint.value')
export AWS_REGION="us-east-1"

# Add Karpenter Helm repo
helm repo add karpenter https://charts.karpenter.sh
helm repo update

# Install Karpenter
helm upgrade --install karpenter karpenter/karpenter \
  --namespace karpenter \
  --create-namespace \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${KARPENTER_IAM_ROLE_ARN} \
  --set settings.clusterName=${CLUSTER_NAME} \
  --set settings.clusterEndpoint=${CLUSTER_ENDPOINT} \
  --set settings.interruptionQueue=${CLUSTER_NAME} \
  --set controller.resources.requests.cpu=1 \
  --set controller.resources.requests.memory=1Gi \
  --set controller.resources.limits.cpu=1 \
  --set controller.resources.limits.memory=1Gi \
  --version 1.0.7 \
  --wait
```

### Step 2: Create NodePool and EC2NodeClass

```bash
cat <<EOF | kubectl apply -f -
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r", "t"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["5"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
  limits:
    cpu: 1000
    memory: 1000Gi
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
---
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2
  role: "NODE_IAM_ROLE_NAME" # Replace with your node IAM role name
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"
  amiSelectorTerms:
    - alias: al2@latest
  userData: |
    #!/bin/bash
    /etc/eks/bootstrap.sh ${CLUSTER_NAME}
  tags:
    karpenter.sh/discovery: "${CLUSTER_NAME}"
    Name: "karpenter-${CLUSTER_NAME}"
EOF
```

### Step 3: Test Karpenter

```bash
# Deploy a test workload
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate
spec:
  replicas: 0
  selector:
    matchLabels:
      app: inflate
  template:
    metadata:
      labels:
        app: inflate
    spec:
      terminationGracePeriodSeconds: 0
      containers:
        - name: inflate
          image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
          resources:
            requests:
              cpu: 1
              memory: 1.5Gi
EOF

# Scale up and watch Karpenter provision nodes
kubectl scale deployment inflate --replicas=10

# Watch nodes being created
kubectl get nodes -w

# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f

# Scale down
kubectl scale deployment inflate --replicas=0

# Watch nodes being terminated
kubectl get nodes -w
```

## AWS Load Balancer Controller Setup

The AWS Load Balancer Controller provisions ALB/NLB for Kubernetes Ingress resources.

### Step 1: Install AWS Load Balancer Controller

```bash
# Get IAM role ARN
export ALB_CONTROLLER_IAM_ROLE_ARN=$(terraform output -json | jq -r '.eks_aws_load_balancer_controller_iam_role_arn.value')

# Add EKS Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${CLUSTER_NAME} \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${ALB_CONTROLLER_IAM_ROLE_ARN} \
  --set region=${AWS_REGION} \
  --set vpcId=$(terraform output -json | jq -r '.vpc_id.value') \
  --wait
```

### Step 2: Verify Installation

```bash
# Check controller pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check CRDs
kubectl get crd | grep elbv2
```

### Step 3: Deploy Test Application with Ingress

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: demo
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: demo
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  namespace: demo
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF

# Wait for ALB to be provisioned
kubectl get ingress -n demo -w

# Get ALB DNS name
kubectl get ingress -n demo nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## External DNS Setup

External DNS automatically creates DNS records for your services and ingresses.

### Step 1: Install External DNS (if enabled in Terraform)

```bash
# Get IAM role ARN
export EXTERNAL_DNS_IAM_ROLE_ARN=$(terraform output -json | jq -r '.eks_external_dns_iam_role_arn.value')

# Install External DNS
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-dns
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${EXTERNAL_DNS_IAM_ROLE_ARN}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: external-dns
rules:
- apiGroups: [""]
  resources: ["services","endpoints","pods"]
  verbs: ["get","watch","list"]
- apiGroups: ["extensions","networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get","watch","list"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: external-dns-viewer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: external-dns
subjects:
- kind: ServiceAccount
  name: external-dns
  namespace: kube-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: kube-system
spec:
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
      - name: external-dns
        image: registry.k8s.io/external-dns/external-dns:v0.14.2
        args:
        - --source=service
        - --source=ingress
        - --domain-filter=example.com # Change to your domain
        - --provider=aws
        - --policy=upsert-only
        - --aws-zone-type=public
        - --registry=txt
        - --txt-owner-id=${CLUSTER_NAME}
      securityContext:
        fsGroup: 65534
EOF
```

## Monitoring and Observability

### CloudWatch Container Insights

If enabled in Terraform, Container Insights automatically collects metrics and logs.

```bash
# Check CloudWatch Observability add-on
kubectl get pods -n amazon-cloudwatch

# View metrics in AWS Console
# Navigate to: CloudWatch → Container Insights → Performance monitoring
```

### Kubernetes Dashboard (Optional)

```bash
# Install Kubernetes Dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Create admin service account
kubectl create serviceaccount dashboard-admin -n kube-system
kubectl create clusterrolebinding dashboard-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:dashboard-admin

# Get access token
kubectl -n kube-system create token dashboard-admin

# Start proxy
kubectl proxy

# Access at: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

## Security Hardening

### 1. Network Policies

```bash
# Enable network policies (if not using Calico)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
```

### 2. Pod Security Standards

```bash
# Label namespaces with Pod Security Standards
kubectl label namespace default pod-security.kubernetes.io/enforce=baseline
kubectl label namespace default pod-security.kubernetes.io/audit=restricted
kubectl label namespace default pod-security.kubernetes.io/warn=restricted
```

### 3. Enable Audit Logging

Already configured in Terraform if `eks_cluster_log_types` includes "audit".

### 4. Secrets Encryption

Already configured in Terraform with KMS envelope encryption.

## Troubleshooting

### Nodes Not Joining

```bash
# Check node IAM role
aws iam get-role --role-name $(terraform output -json | jq -r '.eks_node_iam_role_name.value')

# Check security groups
kubectl get nodes
aws eks describe-cluster --name ${CLUSTER_NAME} --query 'cluster.resourcesVpcConfig.securityGroupIds'

# Check CloudWatch logs
aws logs tail /aws/eks/${CLUSTER_NAME}/cluster --follow
```

### Pods Can't Assume IAM Roles

```bash
# If using Pod Identity
kubectl get podidentityassociations -A

# Check service account annotations
kubectl get sa -n kube-system aws-node -o yaml

# Check pod logs
kubectl logs -n kube-system <pod-name>
```

### Karpenter Not Provisioning

```bash
# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f

# Check NodePool status
kubectl get nodepools

# Check pending pods
kubectl get pods -A --field-selector=status.phase=Pending
```

### ALB Controller Issues

```bash
# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f

# Check Ingress events
kubectl describe ingress <ingress-name> -n <namespace>

# Check TargetGroup bindings
kubectl get targetgroupbindings -A
```

## Cleanup

To destroy the EKS cluster:

```bash
# Delete Helm releases first
helm uninstall karpenter -n karpenter
helm uninstall aws-load-balancer-controller -n kube-system

# Delete test resources
kubectl delete namespace demo

# Destroy with Terraform
cd layers/compute/environments/dev
terraform destroy
```

## Next Steps

1. Set up CI/CD pipelines for application deployments
2. Configure backup and disaster recovery
3. Implement cost optimization strategies
4. Set up centralized logging with ELK or CloudWatch Logs Insights
5. Configure alerts and notifications
6. Implement GitOps with Flux or ArgoCD

## Additional Resources

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Karpenter Documentation](https://karpenter.sh/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/security-best-practices/)
