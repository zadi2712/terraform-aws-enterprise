################################################################################
# VPC Endpoints Module - Basic Test
# Tests basic functionality of the module
################################################################################

# Mock provider configuration for testing
provider "aws" {
  region = "us-east-1"
  
  # Use localstack or mock endpoints for testing
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

# Test variables
variables {
  vpc_id             = "vpc-test123"
  vpc_cidr           = "10.0.0.0/16"
  private_subnet_ids = ["subnet-test1", "subnet-test2"]
  name_prefix        = "test"
}

# Run the module with basic configuration
run "basic_configuration" {
  command = plan

  variables {
    vpc_id             = "vpc-test123"
    vpc_cidr           = "10.0.0.0/16"
    private_subnet_ids = ["subnet-test1", "subnet-test2"]
    name_prefix        = "test"

    endpoints = {
      ec2 = {
        service             = "ec2"
        private_dns_enabled = true
      }
    }
  }

  # Assertions
  assert {
    condition     = length(aws_vpc_endpoint.interface) >= 1
    error_message = "At least one interface endpoint should be created"
  }
  
  assert {
    condition     = aws_security_group.vpc_endpoints[0].name_prefix == "test-vpce-"
    error_message = "Security group name should match expected prefix"
  }
}

# Test gateway endpoint creation
run "gateway_endpoint_configuration" {
  command = plan

  variables {
    vpc_id          = "vpc-test123"
    route_table_ids = ["rtb-test1", "rtb-test2"]
    name_prefix     = "test"
    
    endpoints = {
      s3 = {
        service      = "s3"
        service_type = "Gateway"
      }
    }
  }

  assert {
    condition     = length(aws_vpc_endpoint.gateway) >= 1
    error_message = "Gateway endpoint should be created for S3"
  }
}

# Test without security group creation
run "custom_security_group" {
  command = plan

  variables {
    vpc_id                = "vpc-test123"
    vpc_cidr              = "10.0.0.0/16"
    private_subnet_ids    = ["subnet-test1"]
    name_prefix           = "test"
    create_security_group = false
    security_group_ids    = ["sg-test123"]
    
    endpoints = {
      ec2 = {
        service = "ec2"
      }
    }
  }

  assert {
    condition     = length(aws_security_group.vpc_endpoints) == 0
    error_message = "Security group should not be created when create_security_group is false"
  }
}

# Test multiple endpoints
run "multiple_endpoints" {
  command = plan

  variables {
    vpc_id             = "vpc-test123"
    vpc_cidr           = "10.0.0.0/16"
    private_subnet_ids = ["subnet-test1", "subnet-test2"]
    route_table_ids    = ["rtb-test1"]
    name_prefix        = "test"
    
    endpoints = {
      ec2 = {
        service = "ec2"
      }
      logs = {
        service = "logs"
      }
      s3 = {
        service      = "s3"
        service_type = "Gateway"
      }
    }
  }

  assert {
    condition     = length(aws_vpc_endpoint.interface) == 2
    error_message = "Should create 2 interface endpoints"
  }
  
  assert {
    condition     = length(aws_vpc_endpoint.gateway) == 1
    error_message = "Should create 1 gateway endpoint"
  }
}
