# ECS Quick Start Guide

## 🚀 Quick Setup

### 1. Enable ECS

Edit your environment's `terraform.tfvars`:

```hcl
# layers/compute/environments/dev/terraform.tfvars
enable_ecs = true
```

### 2. Deploy

```bash
cd layers/compute/environments/dev
terraform init -backend-config=backend.conf
terraform plan
terraform apply
```

### 3. Get Outputs

```bash
# Save these for creating services
terraform output ecs_cluster_name
terraform output ecs_task_execution_role_arn
terraform output ecs_task_role_arn
terraform output ecs_security_group_id
```

---

## 📋 Create Your First Service

### 1. Create Task Definition

```bash
cat > task-definition.json <<'EOF'
{
  "family": "myapp",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "REPLACE_WITH_TASK_EXECUTION_ROLE_ARN",
  "taskRoleArn": "REPLACE_WITH_TASK_ROLE_ARN",
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
        "awslogs-create-group": "true",
        "awslogs-group": "/ecs/myapp",
        "awslogs-region": "us-east-1",
        "awslogs-stream-prefix": "app"
      }
    }
  }]
}
EOF

# Register it
aws ecs register-task-definition --cli-input-json file://task-definition.json
```

### 2. Create Service

```bash
# Get values from terraform outputs
CLUSTER_NAME="mycompany-dev-ecs"
SECURITY_GROUP="sg-xxxxx"
SUBNET1="subnet-xxxxx"
SUBNET2="subnet-yyyyy"

aws ecs create-service \
  --cluster $CLUSTER_NAME \
  --service-name myapp \
  --task-definition myapp:1 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={
    subnets=[$SUBNET1,$SUBNET2],
    securityGroups=[$SECURITY_GROUP],
    assignPublicIp=DISABLED
  }"
```

### 3. Verify

```bash
# Check service status
aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services myapp

# List running tasks
aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name myapp
```

---

## 🔍 Debugging with ECS Exec

```bash
# Get task ID
TASK_ID=$(aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name myapp \
  --query 'taskArns[0]' \
  --output text | cut -d'/' -f3)

# Connect to container
aws ecs execute-command \
  --cluster $CLUSTER_NAME \
  --task $TASK_ID \
  --container app \
  --interactive \
  --command "/bin/sh"
```

---

## 📈 Add Auto-Scaling

```bash
# Register scalable target
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/$CLUSTER_NAME/myapp \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 2 \
  --max-capacity 10

# Create CPU-based scaling policy
cat > scaling-policy.json <<'EOF'
{
  "TargetValue": 75.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
  },
  "ScaleOutCooldown": 60,
  "ScaleInCooldown": 60
}
EOF

aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/$CLUSTER_NAME/myapp \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name cpu-scaling \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://scaling-policy.json
```

---

## 🌐 Add Load Balancer

### 1. Create Target Group

```bash
aws elbv2 create-target-group \
  --name myapp-tg \
  --protocol HTTP \
  --port 80 \
  --target-type ip \
  --vpc-id vpc-xxxxx \
  --health-check-path / \
  --health-check-interval-seconds 30
```

### 2. Update Service

```bash
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service myapp \
  --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:...,containerName=app,containerPort=80"
```

---

## 📊 Monitoring

### CloudWatch Container Insights

```bash
# View metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=$CLUSTER_NAME \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### CloudWatch Logs

```bash
# View logs
aws logs tail /ecs/myapp --follow
```

---

## 🔒 Service Discovery (Optional)

### 1. Enable in terraform.tfvars

```hcl
ecs_enable_service_discovery = true
ecs_service_discovery_namespace = "myapp.local"
```

### 2. Apply

```bash
terraform apply
```

### 3. Register Service

```bash
# Get namespace ID
NAMESPACE_ID=$(terraform output -raw ecs_service_discovery_namespace_id)

# Create service in Cloud Map
aws servicediscovery create-service \
  --name api \
  --namespace-id $NAMESPACE_ID \
  --dns-config "NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=60}]"
```

### 4. Update ECS Service

```bash
# Services can now communicate via: api.myapp.local
```

---

## 🎯 Environment-Specific Tips

### Development
- ✅ Use Fargate Spot for cost savings
- ✅ Enable ECS Exec for debugging
- ✅ Short log retention (3 days)

### Production
- ✅ Balanced Fargate/Spot strategy
- ✅ Disable ECS Exec for security
- ✅ Enable service discovery
- ✅ Longer log retention (30 days)

---

## 📚 Common Commands

```bash
# List clusters
aws ecs list-clusters

# Describe cluster
aws ecs describe-clusters --clusters $CLUSTER_NAME

# List services
aws ecs list-services --cluster $CLUSTER_NAME

# Describe service
aws ecs describe-services --cluster $CLUSTER_NAME --services myapp

# List task definitions
aws ecs list-task-definitions

# View task definition
aws ecs describe-task-definition --task-definition myapp:1

# List tasks
aws ecs list-tasks --cluster $CLUSTER_NAME

# Describe task
aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks TASK_ID

# Update service
aws ecs update-service --cluster $CLUSTER_NAME --service myapp --desired-count 4

# Force new deployment
aws ecs update-service --cluster $CLUSTER_NAME --service myapp --force-new-deployment

# Stop task
aws ecs stop-task --cluster $CLUSTER_NAME --task TASK_ID

# Delete service
aws ecs delete-service --cluster $CLUSTER_NAME --service myapp --force
```

---

## 🆘 Troubleshooting

### Tasks Keep Stopping

```bash
# Check stopped reason
aws ecs describe-tasks \
  --cluster $CLUSTER_NAME \
  --tasks TASK_ID \
  --query 'tasks[0].stoppedReason'

# Check CloudWatch logs
aws logs tail /ecs/myapp --since 1h
```

### Cannot Pull Images

```bash
# Verify task execution role
aws iam get-role --role-name $(terraform output -raw ecs_task_execution_role_name)

# Check ECR permissions
aws ecr describe-repositories
aws ecr get-login-password --region us-east-1
```

### Networking Issues

```bash
# Verify security group
aws ec2 describe-security-groups --group-ids $SECURITY_GROUP

# Check VPC endpoints
aws ec2 describe-vpc-endpoints

# Verify subnets have NAT gateway
aws ec2 describe-nat-gateways
```

---

## 📖 Further Reading

- [Complete ECS Module Documentation](modules/ecs/README.md)
- [Compute Layer Documentation](layers/compute/README.md)
- [Update Summary](ECS_MODULE_UPDATE_SUMMARY.md)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/intro.html)

---

**Happy Deploying! 🚀**

