################################################################################
# Security Layer - IAM, KMS, Secrets Manager
################################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = merge(var.common_tags, { Layer = "security" })
  }
}

################################################################################
# KMS Keys
################################################################################

resource "aws_kms_key" "main" {
  description             = "Main encryption key for ${var.environment}"
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  enable_key_rotation     = true

  tags = merge(var.common_tags, { Name = "${var.project_name}-${var.environment}-key" })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}-${var.environment}"
  target_key_id = aws_kms_key.main.key_id
}

################################################################################
# IAM Roles
################################################################################

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


################################################################################
# Store Outputs in SSM Parameter Store
################################################################################

module "ssm_outputs" {
  source = "../../../modules/ssm-outputs"

  project_name = var.project_name
  environment  = var.environment
  layer_name   = "security"

  outputs = {
    kms_key_id                  = aws_kms_key.main.id
    kms_key_arn                 = aws_kms_key.main.arn
    kms_key_alias               = aws_kms_alias.main.name
    ecs_task_execution_role_arn = aws_iam_role.ecs_task_execution.arn
    ecs_task_execution_role_name = aws_iam_role.ecs_task_execution.name
  }

  output_descriptions = {
    kms_key_id                   = "KMS key ID for encryption"
    kms_key_arn                  = "KMS key ARN for encryption"
    kms_key_alias                = "KMS key alias"
    ecs_task_execution_role_arn  = "ECS task execution IAM role ARN"
    ecs_task_execution_role_name = "ECS task execution IAM role name"
  }

  tags = var.common_tags

  depends_on = [
    aws_kms_key.main,
    aws_kms_alias.main,
    aws_iam_role.ecs_task_execution
  ]
}
