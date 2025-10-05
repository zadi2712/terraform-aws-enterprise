################################################################################
# DNS Layer - Route53
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
    tags = merge(var.common_tags, { Layer = "dns" })
  }
}

################################################################################
# Route53 Hosted Zone (if domain_name is provided)
################################################################################

resource "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0

  name = var.domain_name

  tags = merge(var.common_tags, { Name = var.domain_name })
}
