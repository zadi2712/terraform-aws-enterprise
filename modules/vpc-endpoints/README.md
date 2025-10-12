# VPC Endpoints Module

## Overview

Enterprise-grade Terraform module for creating and managing AWS VPC Endpoints (both Interface and Gateway types). This module enables private connectivity to AWS services without requiring internet access, enhancing security posture and reducing data transfer costs.

## Features

### Core Capabilities
- ✅ **Interface Endpoints (PrivateLink)** - Private connectivity to AWS services via ENIs
- ✅ **Gateway Endpoints** - Route table-based connectivity for S3 and DynamoDB
- ✅ **Security Group Management** - Automatic or custom security group configuration
- ✅ **Private DNS Resolution** - Enable private DNS for seamless service access
- ✅ **Multi-Subnet Support** - Deploy across multiple availability zones
- ✅ **Custom IAM Policies** - Fine-grained access control per endpoint
- ✅ **Comprehensive Outputs** - Detailed endpoint information for integration

### Well-Architected Framework Alignment

#### Security
- Private connectivity eliminates public internet exposure
- Security group controls for interface endpoints
- IAM policy support for endpoint access control
- VPC endpoint policies for service-level restrictions

#### Cost Optimization
- Gateway endpoints (S3, DynamoDB) are free
- Reduced NAT Gateway data transfer costs
- Consolidated security group management

#### Performance
- Lower latency through AWS backbone network
- No internet gateway traversal
- Direct private connectivity to services

#### Reliability
- Multi-AZ deployment support
- Automatic DNS resolution
- High availability through AWS-managed infrastructure

## Architecture

### Interface Endpoints (PrivateLink)

```
┌─────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                    │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │Private Subnet│  │Private Subnet│  │Private Subnet│      │
│  │   (AZ-1)     │  │   (AZ-2)     │  │   (AZ-3)     │      │
│  │              │  │              │  │              │      │
│  │    ┌─────┐   │  │    ┌─────┐   │  │    ┌─────┐   │      │
│  │    │ ENI │───┼──┼────│ ENI │───┼──┼────│ ENI │   │      │
│  │    └──┬──┘   │  │    └──┬──┘   │  │    └──┬──┘   │      │
│  │       │      │  │       │      │  │       │      │      │
│  └───────┼──────┘  └───────┼──────┘  └───────┼──────┘      │
│          │                 │                 │              │
│          └─────────────────┴─────────────────┘              │
│                            │                                 │
│                    ┌───────▼────────┐                       │
│                    │  Security Group│                       │
│                    │  (Port 443)    │                       │
│                    └───────┬────────┘                       │
│                            │                                 │
│                    ┌───────▼────────┐                       │
│                    │ VPC Endpoint   │                       │
│                    │ (Interface)    │                       │
│                    └───────┬────────┘                       │
└────────────────────────────┼────────────────────────────────┘
                             │
                    ┌────────▼─────────┐
                    │  AWS Service     │
                    │  (EC2, ECR, etc) │
                    └──────────────────┘
```

### Gateway Endpoints (S3 & DynamoDB)

```
┌─────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                    │
│                                                               │
│  ┌──────────────────────────────────────────────────┐       │
│  │           Route Tables                            │       │
│  │  ┌────────────────────────────────────────┐      │       │
│  │  │ Destination  │  Target                 │      │       │
│  │  ├────────────────────────────────────────┤      │       │
│  │  │ 10.0.0.0/16  │  local                  │      │       │
│  │  │ pl-xxxxx (S3)│  vpce-xxxxx            │      │       │
│  │  └────────────────────────────────────────┘      │       │
│  └────────────────────┬─────────────────────────────┘       │
│                       │                                       │
│              ┌────────▼─────────┐                           │
│              │  Gateway Endpoint │                           │
│              │  (S3/DynamoDB)   │                           │
│              └────────┬─────────┘                           │
└───────────────────────┼───────────────────────────────────────┘
                        │
               ┌────────▼─────────┐
               │  AWS Service     │
               │  (S3, DynamoDB)  │
               └──────────────────┘
```

## Supported AWS Services

### Interface Endpoints (PrivateLink)
- **Compute**: EC2, ECS, Lambda, Auto Scaling
- **Storage**: EFS, S3 (interface endpoint)
- **Database**: RDS, ElastiCache, Redshift
- **Container**: ECR (API & Docker), EKS
- **Security**: KMS, Secrets Manager, ACM
- **Monitoring**: CloudWatch (Logs, Monitoring, Events)
- **Messaging**: SNS, SQS, EventBridge
- **Networking**: ELB, API Gateway, App Mesh
- **Management**: Systems Manager (SSM), CloudFormation
- **Identity**: STS, IAM (limited)
- **Analytics**: Kinesis, Athena, Glue
- **Developer Tools**: CodeBuild, CodeCommit, CodeDeploy, CodePipeline
- **Application Integration**: Step Functions, AppSync

### Gateway Endpoints (Free)
- **S3** - Simple Storage Service
- **DynamoDB** - NoSQL Database

## Usage Examples

### Basic Usage - Interface Endpoints Only

```hcl
module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints"

  vpc_id             = "vpc-abc123"
  vpc_cidr           = "10.0.0.0/16"
  private_subnet_ids = ["subnet-123", "subnet-456", "subnet-789"]
  name_prefix        = "myapp-prod"

  endpoints = {
    ec2 = {
      service             = "ec2"
      private_dns_enabled = true
    }
    s3_interface = {
      service             = "s3"
      private_dns_enabled = true
    }
  }

  tags = {
    Environment = "production"
    Project     = "myapp"
  }
}
```

### Complete Configuration - Interface + Gateway Endpoints

```hcl
module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints"

  # VPC Configuration
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr
  private_subnet_ids = module.vpc.private_subnet_ids
  route_table_ids    = module.vpc.private_route_table_ids
  name_prefix        = "enterprise-prod"

  # Security Group
  create_security_group = true

  # Endpoint Configuration
  endpoints = {
    # Container Services
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
    }
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
    }
    ecs = {
      service             = "ecs"
      private_dns_enabled = true
    }
    
    # Security & Secrets
    kms = {
      service             = "kms"
      private_dns_enabled = true
    }
    secretsmanager = {
      service             = "secretsmanager"
      private_dns_enabled = true
    }
    
    # Monitoring
    logs = {
      service             = "logs"
      private_dns_enabled = true
    }
    monitoring = {
      service             = "monitoring"
      private_dns_enabled = true
    }
    
    # Systems Management
    ssm = {
      service             = "ssm"
      private_dns_enabled = true
    }
    ssmmessages = {
      service             = "ssmmessages"
      private_dns_enabled = true
    }
    ec2messages = {
      service             = "ec2messages"
      private_dns_enabled = true
    }
    
    # Gateway Endpoints (Free)
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
    }
    dynamodb = {
      service         = "dynamodb"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
    }
  }

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

### Advanced - Custom Security Groups and Policies

```hcl
module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints"

  vpc_id                 = module.vpc.vpc_id
  vpc_cidr               = module.vpc.vpc_cidr
  private_subnet_ids     = module.vpc.private_subnet_ids
  name_prefix            = "restricted-prod"
  
  # Use existing security group
  create_security_group  = false
  security_group_ids     = [aws_security_group.custom_vpce.id]

  endpoints = {
    s3_interface = {
      service             = "s3"
      private_dns_enabled = false
      # Custom policy for S3 endpoint
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect    = "Allow"
          Principal = "*"
          Action = [
            "s3:GetObject",
            "s3:PutObject"
          ]
          Resource = [
            "arn:aws:s3:::my-bucket/*"
          ]
        }]
      })
    }
    
    secretsmanager = {
      service             = "secretsmanager"
      private_dns_enabled = true
      # Deploy to specific subnets only
      subnet_ids          = [module.vpc.private_subnet_ids[0]]
      # Use different security group
      security_group_ids  = [aws_security_group.secrets_vpce.id]
    }
  }

  tags = {
    Compliance = "PCI-DSS"
  }
}
```

### Cross-Account VPC Endpoint

```hcl
module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints"

  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr
  private_subnet_ids = module.vpc.private_subnet_ids
  name_prefix        = "cross-account"

  endpoints = {
    custom_service = {
      service      = "com.amazonaws.vpce.us-east-1.vpce-svc-xxxxxx"
      auto_accept  = true
      tags = {
        Type = "CrossAccount"
      }
    }
  }
}
```

## Cost Optimization Strategies

### 1. Use Gateway Endpoints (Free)
```hcl
# Gateway endpoints for S3 and DynamoDB are FREE
endpoints = {
  s3 = {
    service      = "s3"
    service_type = "Gateway"
  }
  dynamodb = {
    service      = "dynamodb"
    service_type = "Gateway"
  }
}
```

### 2. Single vs Multi-AZ Deployment
```hcl
# Cost-optimized: Deploy to single subnet (lower cost, lower availability)
endpoints = {
  ec2 = {
    service    = "ec2"
    subnet_ids = [module.vpc.private_subnet_ids[0]]
  }
}

# High availability: Deploy across all AZs (higher cost, better resilience)
endpoints = {
  ec2 = {
    service    = "ec2"
    subnet_ids = module.vpc.private_subnet_ids  # All subnets
  }
}
```

### 3. Consolidated vs Separate Endpoints
```hcl
# Use same security group for all endpoints (recommended)
create_security_group = true  # One SG for all

# vs creating separate security groups per service (higher cost)
```

## Security Best Practices

### 1. Restrict Security Group Access
```hcl
# Recommended: Create restrictive security group
resource "aws_security_group" "vpce_custom" {
  name_prefix = "vpce-restricted-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from VPC only"
  }

  # No egress rules = deny all outbound
  tags = {
    Name = "vpce-restricted"
  }
}

module "vpc_endpoints" {
  # ...
  create_security_group = false
  security_group_ids    = [aws_security_group.vpce_custom.id]
}
```

### 2. Implement VPC Endpoint Policies
```hcl
# Restrict S3 endpoint to specific buckets
locals {
  s3_endpoint_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSpecificBuckets"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:*"]
        Resource = [
          "arn:aws:s3:::my-app-bucket",
          "arn:aws:s3:::my-app-bucket/*"
        ]
      }
    ]
  })
}

endpoints = {
  s3 = {
    service      = "s3"
    service_type = "Gateway"
    policy       = local.s3_endpoint_policy
  }
}
```

### 3. Enable Private DNS
```hcl
# Always enable private DNS for seamless integration
endpoints = {
  secretsmanager = {
    service             = "secretsmanager"
    private_dns_enabled = true  # Applications use standard AWS endpoints
  }
}
```

### 4. Implement Defense in Depth
```hcl
# Layer 1: VPC Endpoint Policy
# Layer 2: Security Group
# Layer 3: IAM Policies
# Layer 4: Resource Policies (S3 bucket policy, etc.)
```

## Monitoring and Troubleshooting

### CloudWatch Metrics

VPC Endpoints automatically provide CloudWatch metrics:

- **ActiveConnections** - Number of active connections
- **BytesReceived** - Bytes received through the endpoint
- **BytesSent** - Bytes sent through the endpoint
- **PacketsReceived** - Packets received
- **PacketsSent** - Packets sent

### VPC Flow Logs

Enable VPC Flow Logs to monitor endpoint traffic:

```hcl
# In VPC module
enable_flow_logs = true
flow_logs_retention_in_days = 30
```

### Common Issues and Solutions

#### Issue: Cannot connect to service through endpoint

**Check 1: Security Group**
```bash
# Verify security group allows port 443
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx \
  --query 'SecurityGroups[0].IpPermissions'
```

**Check 2: Private DNS**
```bash
# Verify private DNS is enabled
aws ec2 describe-vpc-endpoints \
  --vpc-endpoint-ids vpce-xxxxx \
  --query 'VpcEndpoints[0].PrivateDnsEnabled'
```

**Check 3: Route Tables (Gateway Endpoints)**
```bash
# Verify route table has endpoint route
aws ec2 describe-route-tables \
  --route-table-ids rtb-xxxxx \
  --query 'RouteTables[0].Routes'
```

#### Issue: DNS resolution not working

**Solution 1: Verify VPC DNS settings**
```hcl
# Ensure these are enabled in VPC
enable_dns_hostnames = true
enable_dns_support   = true
```

**Solution 2: Check subnet DNS resolution**
```bash
# From instance, verify DNS resolution
nslookup ec2.us-east-1.amazonaws.com
# Should resolve to private IP (10.x.x.x)
```

#### Issue: High costs

**Solution 1: Use Gateway Endpoints**
```hcl
# S3 and DynamoDB should use Gateway endpoints (free)
endpoints = {
  s3       = { service_type = "Gateway" }
  dynamodb = { service_type = "Gateway" }
}
```

**Solution 2: Reduce endpoint count**
```hcl
# Only create endpoints for frequently used services
# Remove endpoints for services accessed occasionally
```

**Solution 3: Single-AZ deployment for dev/test**
```hcl
# Development environment
endpoints = {
  ec2 = {
    service    = "ec2"
    subnet_ids = [module.vpc.private_subnet_ids[0]]  # One subnet only
  }
}
```

## Testing VPC Endpoints

### Test Interface Endpoint

```bash
# From EC2 instance in private subnet
# Should resolve to private IP (10.x.x.x)
nslookup ec2.us-east-1.amazonaws.com

# Test connectivity
aws ec2 describe-instances --region us-east-1 --endpoint-url https://ec2.us-east-1.amazonaws.com

# Verify using private IP
curl -v https://ec2.us-east-1.amazonaws.com 2>&1 | grep "Connected to"
```

### Test Gateway Endpoint

```bash
# From EC2 instance, access S3
aws s3 ls

# Verify traffic goes through endpoint (check VPC Flow Logs)
# Source IP should be within VPC CIDR, not NAT Gateway IP
```

### Verify DNS Resolution

```python
import socket

# Should return private IPs for interface endpoints
services = [
    'ec2.us-east-1.amazonaws.com',
    'logs.us-east-1.amazonaws.com',
    'secretsmanager.us-east-1.amazonaws.com'
]

for service in services:
    ip = socket.gethostbyname(service)
    print(f"{service}: {ip}")
    # Should print 10.x.x.x addresses
```

## Performance Optimization

### 1. Multi-AZ Deployment

Deploy endpoints across all availability zones for:
- Lower latency (closer proximity)
- Higher availability
- Better fault tolerance

```hcl
endpoints = {
  s3_interface = {
    service    = "s3"
    subnet_ids = module.vpc.private_subnet_ids  # All AZs
  }
}
```

### 2. DNS Caching

Enable DNS caching in applications to reduce DNS lookup overhead:

```python
# Python example
import boto3
from botocore.config import Config

config = Config(
    max_pool_connections=50,  # Reuse connections
    tcp_keepalive=True
)

client = boto3.client('s3', config=config)
```

### 3. Connection Pooling

Reuse connections to VPC endpoints:

```javascript
// Node.js example
const AWS = require('aws-sdk');

AWS.config.update({
  httpOptions: {
    agent: new https.Agent({
      keepAlive: true,
      maxSockets: 50
    })
  }
});
```

## Compliance and Governance

### PCI-DSS Considerations

```hcl
# Ensure cardholder data never traverses public internet
endpoints = {
  # All services handling payment data
  rds             = { service = "rds" }
  secretsmanager  = { service = "secretsmanager" }
  kms             = { service = "kms" }
  
  # Logging for audit trail
  logs            = { service = "logs" }
  
  # No public S3 access
  s3 = {
    service      = "s3"
    service_type = "Gateway"
    policy       = local.pci_s3_policy
  }
}
```

### HIPAA Considerations

```hcl
# PHI must remain on AWS private network
endpoints = {
  # All services handling PHI
  rds            = { service = "rds" }
  elasticache    = { service = "elasticache" }
  secretsmanager = { service = "secretsmanager" }
  kms            = { service = "kms" }
  
  # S3 for HIPAA-eligible storage
  s3 = {
    service      = "s3"
    service_type = "Gateway"
    policy       = local.hipaa_s3_policy
  }
}
```

### Tagging Strategy

```hcl
tags = {
  # Governance
  DataClassification = "Confidential"
  Compliance         = "PCI-DSS"
  
  # Operations
  ManagedBy         = "Terraform"
  BackupPolicy      = "Daily"
  
  # Financial
  CostCenter        = "Engineering"
  Project           = "CustomerPortal"
  
  # Technical
  Layer             = "Network"
  Service           = "VPCEndpoint"
}
```

## Migration Guide

### From NAT Gateway to VPC Endpoints

**Step 1: Assess Current Traffic**
```bash
# Review VPC Flow Logs to identify AWS service traffic
aws logs filter-log-events \
  --log-group-name /aws/vpc/flowlogs \
  --filter-pattern "[version, account, eni, source, destination, srcport, destport, protocol, packets, bytes, start, end, action, logstatus]" \
  --query 'events[].message' \
  --output text | grep -E "443|80"
```

**Step 2: Create VPC Endpoints**
```hcl
# Start with high-traffic services
module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints"
  # Configuration...
}
```

**Step 3: Verify Connectivity**
```bash
# Test from EC2 instance
aws s3 ls  # Should work via endpoint
aws ec2 describe-instances  # Should work via endpoint
```

**Step 4: Remove NAT Gateway Routes** (optional)
```hcl
# Only after confirming all traffic routes through endpoints
```

**Cost Savings Calculation:**
```
NAT Gateway: $0.045/hour + $0.045/GB
VPC Endpoint: $0.01/hour + $0.01/GB

For 1TB/month:
NAT Gateway: $32.40 + $46.08 = $78.48
VPC Endpoint: $7.20 + $10.24 = $17.44

Savings: $61.04/month (78% reduction)
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vpc_id | ID of the VPC where endpoints will be created | `string` | n/a | yes |
| endpoints | Map of VPC endpoints to create | `map(object)` | `{}` | no |
| vpc_cidr | CIDR block of the VPC (required for security group rules) | `string` | `null` | no |
| name_prefix | Prefix for resource names | `string` | `"vpc"` | no |
| private_subnet_ids | List of private subnet IDs for interface endpoints | `list(string)` | `[]` | no |
| route_table_ids | List of route table IDs for gateway endpoints | `list(string)` | `[]` | no |
| create_security_group | Whether to create a security group for VPC endpoints | `bool` | `true` | no |
| security_group_ids | List of security group IDs to attach to endpoints | `list(string)` | `[]` | no |
| tags | Common tags to apply to all resources | `map(string)` | `{}` | no |

### Endpoint Object Structure

```hcl
{
  service             = string              # AWS service name (required)
  service_type        = string              # "Interface" or "Gateway" (default: "Interface")
  private_dns_enabled = bool                # Enable private DNS (default: true)
  subnet_ids          = list(string)        # Subnet IDs (optional)
  security_group_ids  = list(string)        # Security group IDs (optional)
  route_table_ids     = list(string)        # Route table IDs for Gateway endpoints (optional)
  policy              = string              # IAM policy document (optional)
  auto_accept         = bool                # Auto-accept endpoint connection (optional)
  tags                = map(string)         # Additional tags (optional)
  timeout_create      = string              # Create timeout (default: "10m")
  timeout_update      = string              # Update timeout (default: "10m")
  timeout_delete      = string              # Delete timeout (default: "10m")
}
```

## Outputs

| Name | Description |
|------|-------------|
| security_group_id | ID of the VPC endpoints security group |
| security_group_arn | ARN of the VPC endpoints security group |
| security_group_name | Name of the VPC endpoints security group |
| interface_endpoints | Map of interface VPC endpoint IDs |
| interface_endpoint_arns | Map of interface VPC endpoint ARNs |
| interface_endpoint_dns_entries | Map of interface VPC endpoint DNS entries |
| interface_endpoint_network_interface_ids | Map of interface VPC endpoint network interface IDs |
| interface_endpoint_state | Map of interface VPC endpoint states |
| gateway_endpoints | Map of gateway VPC endpoint IDs |
| gateway_endpoint_arns | Map of gateway VPC endpoint ARNs |
| gateway_endpoint_state | Map of gateway VPC endpoint states |
| gateway_endpoint_prefix_list_ids | Map of gateway VPC endpoint prefix list IDs |
| all_endpoints | Map of all VPC endpoint IDs (interface and gateway) |
| all_endpoint_arns | Map of all VPC endpoint ARNs |
| endpoint_count | Total number of VPC endpoints created |

## Module Dependencies

This module can be used independently but is typically integrated with:

- **VPC Module** - Provides VPC ID, subnet IDs, and CIDR blocks
- **Security Group Module** - Can provide custom security groups
- **Route 53 Module** - For custom DNS resolution (advanced scenarios)

## Examples

See the [examples](../../layers/networking/environments/) directory for complete, working examples:

- **Basic** - Minimal configuration with essential endpoints
- **Complete** - Full enterprise setup with all endpoints
- **Custom** - Advanced configuration with custom policies
- **Cross-Account** - VPC endpoint sharing across accounts

## References

### AWS Documentation
- [VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [Gateway Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html)
- [Interface Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/create-interface-endpoint.html)
- [VPC Endpoint Services](https://docs.aws.amazon.com/vpc/latest/privatelink/privatelink-access-aws-services.html)
- [VPC Endpoint Policies](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-access.html)

### Best Practices
- [AWS PrivateLink Best Practices](https://docs.aws.amazon.com/whitepapers/latest/aws-privatelink/best-practices.html)
- [VPC Security Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [Cost Optimization for VPC Endpoints](https://aws.amazon.com/blogs/networking-and-content-delivery/reduce-cost-and-increase-security-with-amazon-vpc-endpoints/)

### Terraform Resources
- [aws_vpc_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint)
- [aws_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)

## License

This module is maintained by the Platform Engineering team.

## Support

For issues, questions, or contributions:
- Create an issue in the repository
- Contact the Platform Engineering team
- Refer to the [troubleshooting guide](#monitoring-and-troubleshooting)

---

**Last Updated**: October 2025
**Module Version**: 1.0.0
**Terraform Version**: >= 1.5.0
**AWS Provider Version**: >= 5.0
