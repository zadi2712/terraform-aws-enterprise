################################################################################
# ECS Module - Container Orchestration
################################################################################

resource "aws_ecs_cluster" "this" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = var.container_insights_enabled ? "enabled" : "disabled"
  }

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = var.kms_key_arn != null ? true : false
        cloud_watch_log_group_name     = var.enable_execute_command ? aws_cloudwatch_log_group.exec_command[0].name : null
      }
    }
  }

  tags = merge(var.tags, { Name = var.cluster_name })
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = var.capacity_providers

  dynamic "default_capacity_provider_strategy" {
    for_each = var.default_capacity_provider_strategy
    content {
      capacity_provider = default_capacity_provider_strategy.value.capacity_provider
      weight            = default_capacity_provider_strategy.value.weight
      base              = lookup(default_capacity_provider_strategy.value, "base", null)
    }
  }
}

################################################################################
# CloudWatch Log Group for ECS Exec
################################################################################

resource "aws_cloudwatch_log_group" "exec_command" {
  count             = var.enable_execute_command ? 1 : 0
  name              = "/aws/ecs/${var.cluster_name}/exec"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, { Name = "${var.cluster_name}-exec-logs" })
}

################################################################################
# Service Discovery Namespace (Optional)
################################################################################

resource "aws_service_discovery_private_dns_namespace" "this" {
  count       = var.enable_service_discovery ? 1 : 0
  name        = var.service_discovery_namespace
  description = "Service discovery namespace for ${var.cluster_name}"
  vpc         = var.vpc_id

  tags = merge(var.tags, { Name = var.service_discovery_namespace })
}

################################################################################
# IAM Roles for ECS Tasks
################################################################################

# Task Execution Role (used by ECS agent)
resource "aws_iam_role" "task_execution" {
  count = var.create_task_execution_role ? 1 : 0
  name  = "${var.cluster_name}-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, { Name = "${var.cluster_name}-task-execution-role" })
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  count      = var.create_task_execution_role ? 1 : 0
  role       = aws_iam_role.task_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for pulling from ECR and accessing Secrets Manager/SSM
resource "aws_iam_role_policy" "task_execution_additional" {
  count = var.create_task_execution_role ? 1 : 0
  name  = "additional-permissions"
  role  = aws_iam_role.task_execution[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "ssm:GetParameters",
          "ssm:GetParameter",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

# Task Role (used by application code)
resource "aws_iam_role" "task" {
  count = var.create_task_role ? 1 : 0
  name  = "${var.cluster_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, { Name = "${var.cluster_name}-task-role" })
}

# Allow ECS Exec
resource "aws_iam_role_policy" "task_exec_command" {
  count = var.enable_execute_command && var.create_task_role ? 1 : 0
  name  = "ecs-exec-permissions"
  role  = aws_iam_role.task[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

################################################################################
# Security Group for ECS Tasks
################################################################################

resource "aws_security_group" "ecs_tasks" {
  count       = var.create_security_group ? 1 : 0
  name        = "${var.cluster_name}-tasks-sg"
  description = "Security group for ECS tasks in ${var.cluster_name}"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.cluster_name}-tasks-sg" })
}

resource "aws_security_group_rule" "ecs_tasks_egress" {
  count             = var.create_security_group ? 1 : 0
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_tasks[0].id
  description       = "Allow all outbound traffic"
}

# Ingress rules from ALB
resource "aws_security_group_rule" "ecs_tasks_ingress_alb" {
  count                    = var.create_security_group && var.alb_security_group_id != null ? 1 : 0
  type                     = "ingress"
  from_port                = var.task_container_port
  to_port                  = var.task_container_port
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id
  security_group_id        = aws_security_group.ecs_tasks[0].id
  description              = "Allow traffic from ALB"
}
