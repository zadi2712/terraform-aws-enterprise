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

for layer in LAYERS:
    for env, config in ENVIRONMENTS.items():
        env_dir = Path(f"{BASE_DIR}/layers/{layer}/environments/{env}")
        env_dir.mkdir(parents=True, exist_ok=True)
        
        # Create backend.conf
        backend_conf = f"""bucket         = "terraform-state-{env}-${{AWS_ACCOUNT_ID}}"
key            = "layers/{layer}/{env}/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock-{env}"
encrypt        = true
"""
        with open(env_dir / "backend.conf", "w") as f:
            f.write(backend_conf)
        
        # Create terraform.tfvars
        tfvars = f"""################################################################################
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
"""
        with open(env_dir / "terraform.tfvars", "w") as f:
            f.write(tfvars)

print("✅ All environment files generated successfully!")
