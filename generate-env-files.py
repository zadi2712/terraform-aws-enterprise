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
    },
    "qa": {
        "vpc_cidr": "10.1.0.0/16",
        "azs": '["us-east-1a", "us-east-1b"]',
        "single_nat": "false",
        "retention": "14",
    },
    "uat": {
        "vpc_cidr": "10.2.0.0/16",
        "azs": '["us-east-1a", "us-east-1b", "us-east-1c"]',
        "single_nat": "false",
        "retention": "30",
    },
    "prod": {
        "vpc_cidr": "10.3.0.0/16",
        "azs": '["us-east-1a", "us-east-1b", "us-east-1c"]',
        "single_nat": "false",
        "retention": "90",
    }
}

def create_backend_conf(layer, env):
    """Create backend.conf file"""
    content = f'''bucket         = "terraform-state-{env}-${{AWS_ACCOUNT_ID}}"
key            = "layers/{layer}/{env}/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock-{env}"
encrypt        = true
'''
    return content

def create_terraform_tfvars(layer, env, config):
    """Create terraform.tfvars file"""
    content = f'''################################################################################
# {layer.capitalize()} Layer - {env.upper()} Environment Configuration
################################################################################

# General Configuration
environment  = "{env}"
aws_region   = "us-east-1"
project_name = "enterprise"

# Common Tags
common_tags = {{
  Environment = "{env}"
  Project     = "enterprise-infrastructure"
  ManagedBy   = "terraform"
  Layer       = "{layer}"
  CostCenter  = "engineering"
  Owner       = "platform-team"
  Compliance  = "pci-dss"
}}
'''
    return content

# Generate files
for layer in LAYERS:
    for env, config in ENVIRONMENTS.items():
        env_dir = Path(f"{BASE_DIR}/layers/{layer}/environments/{env}")
        env_dir.mkdir(parents=True, exist_ok=True)
        
        # Write backend.conf
        backend_file = env_dir / "backend.conf"
        with open(backend_file, 'w') as f:
            f.write(create_backend_conf(layer, env))
        
        # Write terraform.tfvars
        tfvars_file = env_dir / "terraform.tfvars"
        with open(tfvars_file, 'w') as f:
            f.write(create_terraform_tfvars(layer, env, config))

print("✅ All environment files generated successfully!")
print(f"Generated files for {len(LAYERS)} layers × {len(ENVIRONMENTS)} environments = {len(LAYERS) * len(ENVIRONMENTS)} configs")
