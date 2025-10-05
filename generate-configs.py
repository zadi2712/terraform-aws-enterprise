#!/usr/bin/env python3
"""
Generate backend.conf and terraform.tfvars for all layers and environments
"""

import os
from pathlib import Path

BASE_DIR = "/Users/diego/terraform-aws-enterprise"
LAYERS = ["compute", "database", "storage", "security", "dns", "monitoring"]
ENVIRONMENTS = {
    "dev": {
        "vpc_cidr": "10.0.0.0/16",
        "azs": '["us-east-1a", "us-east-1b"]',
        "single_nat": "true",
        "retention": "7",
        "instance_size": "t3.small",
        "rds_instance": "db.t3.small",
        "multi_az": "false",
    },
    "qa": {
        "vpc_cidr": "10.1.0.0/16",
        "azs": '["us-east-1a", "us-east-1b", "us-east-1c"]',
        "single_nat": "false",
        "retention": "14",
        "instance_size": "t3.medium",
        "rds_instance": "db.t3.medium",
        "multi_az": "true",
    },
    "uat": {
        "vpc_cidr": "10.2.0.0/16",
        "azs": '["us-east-1a", "us-east-1b", "us-east-1c"]',
        "single_nat": "false",
        "retention": "30",
        "instance_size": "t3.large",
        "rds_instance": "db.r5.large",
        "multi_az": "true",
    },
    "prod": {
        "vpc_cidr": "10.3.0.0/16",
        "azs": '["us-east-1a", "us-east-1b", "us-east-1c"]',
        "single_nat": "false",
        "retention": "90",
        "instance_size": "t3.xlarge",
        "rds_instance": "db.r5.xlarge",
        "multi_az": "true",
    },
}

for layer in LAYERS:
    for env, config in ENVIRONMENTS.items():
        env_dir = f"{BASE_DIR}/layers/{layer}/environments/{env}"
        Path(env_dir).mkdir(parents=True, exist_ok=True)
        
        # Create backend.conf
        backend_content = f'''bucket         = "terraform-state-{env}-${{AWS_ACCOUNT_ID}}"
key            = "layers/{layer}/{env}/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock-{env}"
encrypt        = true
'''
        with open(f"{env_dir}/backend.conf", "w") as f:
            f.write(backend_content)
        
        # Create terraform.tfvars
        tfvars_content = f'''################################################################################
# {layer.upper()} Layer - {env.upper()} Environment Configuration
################################################################################

# General Configuration
environment  = "{env}"
aws_region   = "us-east-1"
project_name = "enterprise"

# Instance Sizing
instance_type     = "{config['instance_size']}"
rds_instance_type = "{config['rds_instance']}"
enable_multi_az   = {config['multi_az']}

# Backup Configuration
backup_retention_days = {config['retention']}

# Common Tags
common_tags = {{
  Environment = "{env}"
  Project     = "enterprise-infrastructure"
  ManagedBy   = "terraform"
  Layer       = "{layer}"
  CostCenter  = "engineering"
  Owner       = "platform-team"
}}
'''
        with open(f"{env_dir}/terraform.tfvars", "w") as f:
            f.write(tfvars_content)

print("✅ All environment configuration files generated!")
