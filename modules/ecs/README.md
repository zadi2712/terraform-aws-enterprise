# ECS Module

## Description

Enterprise-ready Amazon ECS (Elastic Container Service) module for deploying containerized applications with Fargate and EC2 capacity providers.

## Features

- **Cluster Management**: Full ECS cluster with Container Insights
- **Capacity Providers**: Support for FARGATE, FARGATE_SPOT, and EC2
- **IAM Roles**: Automatic creation of task execution and task roles
- **Service Discovery**: AWS Cloud Map integration for service-to-service communication
- **Security Groups**: Automated security group creation for tasks
- **ECS Exec**: Debugging support with SSM Session Manager
- **Logging**: CloudWatch Logs integration with encryption
- **Network Isolation**: VPC integration with private subnets

## Resources Created

- `aws_ecs_cluster` - ECS cluster with Container Insights
- `aws_ecs_cluster_capacity_providers` - Capacity provider configuration
- `aws_iam_role` - Task execution and task IAM roles
- `aws_iam_role_policy` - IAM policies for ECR, Secrets Manager, SSM
- `aws_security_group` - Security group for ECS tasks
- `aws_service_discovery_private_dns_namespace` - Cloud Map namespace (optional)
- `aws_cloudwatch_log_group` - CloudWatch Logs for ECS Exec (optional)

## Usage

### Basic ECS Cluster

```hcl
module "ecs" {
  source = "../../modules/ecs"

  cluster_name               = "myapp-prod-ecs"
  container_insights_enabled = true
  
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  
  default_capacity_provider_strategy = [
    {
      capacity_provider = "FARGATE"
      weight            = 1
      base              = 1
    }
  ]

  tags = {
    Environment = "production"
    Project     = "myapp"
    ManagedBy   = "terraform"
  }
}
```

### Production ECS Cluster with Full Features

```hcl
module "ecs" {
  source = "../../modules/ecs"

  cluster_name               = "myapp-prod-ecs"
  container_insights_enabled = true
  
  # Network configuration
  vpc_id                = module.vpc.vpc_id
  create_security_group = true
  alb_security_group_id = module.alb.security_group_id
  task_container_port   = 8080
  
  # Capacity providers
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  
  default_capacity_provider_strategy = [
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
  
  # IAM roles
  create_task_execution_role = true
  create_task_role           = true
  
  # Service discovery
  enable_service_discovery    = true
  service_discovery_namespace = "myapp.local"
  
  # Debugging and logging
  enable_execute_command = true
  log_retention_days     = 30
  kms_key_arn            = module.kms.key_arn
  
  tags = {
    Environment = "production"
    Project     = "myapp"
    ManagedBy   = "terraform"
  }
}
```

### ECS with Service Discovery

```hcl
module "ecs" {
  source = "../../modules/ecs"

  cluster_name = "services-prod-ecs"
  vpc_id       = module.vpc.vpc_id
  
  # Enable service discovery for microservices
  enable_service_discovery    = true
  service_discovery_namespace = "services.internal"
  
  create_task_execution_role = true
  create_task_role           = true
  
  tags = {
    Environment = "production"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | ECS cluster name | `string` | n/a | yes |
| container_insights_enabled | Enable Container Insights | `bool` | `true` | no |
| capacity_providers | List of capacity providers | `list(string)` | `["FARGATE", "FARGATE_SPOT"]` | no |
| default_capacity_provider_strategy | Default capacity provider strategy | `list(any)` | `[]` | no |
| vpc_id | VPC ID for ECS tasks and service discovery | `string` | `null` | no |
| create_security_group | Whether to create a security group for ECS tasks | `bool` | `false` | no |
| alb_security_group_id | Security group ID of ALB to allow ingress from | `string` | `null` | no |
| task_container_port | Container port for tasks | `number` | `8080` | no |
| enable_service_discovery | Enable AWS Cloud Map service discovery | `bool` | `false` | no |
| service_discovery_namespace | Service discovery namespace | `string` | `"local"` | no |
| create_task_execution_role | Whether to create a task execution role | `bool` | `false` | no |
| create_task_role | Whether to create a task role | `bool` | `false` | no |
| log_retention_days | CloudWatch log retention in days | `number` | `7` | no |
| enable_execute_command | Enable ECS Exec for debugging | `bool` | `false` | no |
| kms_key_arn | KMS key ARN for encryption | `string` | `null` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | ECS cluster ID |
| cluster_arn | ECS cluster ARN |
| cluster_name | ECS cluster name |
| task_execution_role_arn | ARN of the task execution role |
| task_execution_role_name | Name of the task execution role |
| task_role_arn | ARN of the task role |
| task_role_name | Name of the task role |
| security_group_id | Security group ID for ECS tasks |
| security_group_arn | Security group ARN for ECS tasks |
| service_discovery_namespace_id | Service discovery namespace ID |
| service_discovery_namespace_arn | Service discovery namespace ARN |
| service_discovery_namespace_hosted_zone | Service discovery Route53 hosted zone ID |
| exec_command_log_group_name | CloudWatch log group name for ECS Exec |
| exec_command_log_group_arn | CloudWatch log group ARN for ECS Exec |

## IAM Roles

### Task Execution Role

The task execution role is used by the ECS agent to:
- Pull container images from ECR
- Retrieve secrets from Secrets Manager
- Retrieve parameters from SSM Parameter Store
- Write logs to CloudWatch Logs
- Decrypt with KMS

### Task Role

The task role is used by your application code to:
- Access AWS services (S3, DynamoDB, etc.)
- Use ECS Exec for debugging

## Security Groups

When `create_security_group = true`, the module creates a security group with:
- Egress: Allow all outbound traffic
- Ingress: Allow traffic from ALB on the specified container port

## Service Discovery

When `enable_service_discovery = true`, the module creates:
- Private DNS namespace in Route53
- Enables service-to-service communication via DNS

Services can communicate using: `service-name.namespace` (e.g., `api.myapp.local`)

## ECS Exec

When `enable_execute_command = true`:
- Enables interactive shell access to running containers
- Uses AWS Systems Manager Session Manager
- Logs all exec sessions to CloudWatch

Usage:
```bash
aws ecs execute-command \
  --cluster myapp-prod-ecs \
  --task <task-id> \
  --container <container-name> \
  --interactive \
  --command "/bin/bash"
```

## Capacity Providers

### FARGATE
- Serverless compute for containers
- No server management
- Pay per vCPU and memory used
- Best for: Variable workloads, development, testing

### FARGATE_SPOT
- Up to 70% discount vs FARGATE
- Can be interrupted with 2-minute warning
- Best for: Fault-tolerant, stateless workloads

### EC2
- Run on your own EC2 instances
- More control over instance types
- Better cost optimization for steady-state workloads
- Requires Auto Scaling Group setup

## Well-Architected Framework

This module implements AWS Well-Architected Framework best practices:

### Operational Excellence
- Infrastructure as Code with Terraform
- Container Insights for monitoring
- ECS Exec for debugging
- CloudWatch Logs integration

### Security
- IAM roles with least privilege
- Security groups for network isolation
- KMS encryption for logs
- Private service discovery
- VPC integration

### Reliability
- Multi-AZ deployment support
- Fargate for serverless reliability
- Service discovery for resilience
- Health checks via ALB integration

### Performance Efficiency
- Fargate automatic scaling
- Multiple capacity providers
- Optimized networking
- Container Insights metrics

### Cost Optimization
- Fargate Spot for cost savings
- Right-sized capacity provider strategies
- Log retention policies
- Resource tagging

## Examples

### Creating ECS Services

After creating the cluster, you can create services:

```hcl
resource "aws_ecs_task_definition" "app" {
  family                   = "myapp"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = module.ecs.task_execution_role_arn
  task_role_arn            = module.ecs.task_role_arn

  container_definitions = jsonencode([{
    name  = "app"
    image = "nginx:latest"
    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/myapp"
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "app"
      }
    }
  }])
}

resource "aws_ecs_service" "app" {
  name            = "myapp"
  cluster         = module.ecs.cluster_id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 3

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [module.ecs.security_group_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 80
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }

  enable_execute_command = true
}
```

## Best Practices

1. **Use Fargate for most workloads** - Simplifies operations
2. **Enable Container Insights** - Essential for monitoring
3. **Use service discovery** - For microservices architectures
4. **Enable ECS Exec in dev** - Disable in production for security
5. **Use task roles** - Grant minimal permissions needed
6. **Configure health checks** - Via ALB target groups
7. **Set appropriate log retention** - Balance cost and compliance
8. **Use private subnets** - For enhanced security
9. **Tag all resources** - For cost allocation and management
10. **Use Fargate Spot** - For cost-tolerant workloads

## Troubleshooting

### Tasks not starting
```bash
# Check service events
aws ecs describe-services --cluster myapp-prod-ecs --services myapp

# Check task stopped reason
aws ecs describe-tasks --cluster myapp-prod-ecs --tasks <task-id>
```

### Cannot pull ECR images
- Verify task execution role has ECR permissions
- Check VPC has NAT Gateway or VPC endpoints for ECR

### Service discovery not working
- Verify namespace exists
- Check service registration
- Verify security groups allow traffic

## Related Modules

- [ALB Module](../alb/README.md) - For load balancing
- [ECR Module](../ecr/README.md) - For container images
- [VPC Module](../vpc/README.md) - For networking

## References

- [ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/intro.html)
- [Fargate Pricing](https://aws.amazon.com/fargate/pricing/)
- [ECS Exec](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html)
