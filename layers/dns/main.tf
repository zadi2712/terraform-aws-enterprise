################################################################################
# DNS Layer - Route53
################################################################################

terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
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


################################################################################
# Store Outputs in SSM Parameter Store
################################################################################

module "ssm_outputs" {
  source = "../../../modules/ssm-outputs"

  project_name = var.project_name
  environment  = var.environment
  layer_name   = "dns"

  outputs = {
    hosted_zone_id = var.domain_name != "" ? aws_route53_zone.main[0].zone_id : null
    name_servers   = var.domain_name != "" ? aws_route53_zone.main[0].name_servers : null
    domain_name    = var.domain_name
  }

  output_descriptions = {
    hosted_zone_id = "Route53 hosted zone ID"
    name_servers   = "Route53 name servers for domain delegation"
    domain_name    = "Domain name managed by Route53"
  }

  tags = var.common_tags

  depends_on = [
    aws_route53_zone.main
  ]
}
