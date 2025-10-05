################################################################################
# VPC Module - Main Configuration
# Purpose: Create VPC with multi-AZ architecture
# Well-Architected Pillars: Reliability, Security, Performance
################################################################################

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    var.tags,
    {
      Name        = var.vpc_name
      Environment = var.environment
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-igw"
    }
  )
}

################################################################################
# Public Subnets
################################################################################

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index % length(var.availability_zones)]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-public-${var.availability_zones[count.index % length(var.availability_zones)]}"
      Tier = "public"
      Type = "public"
    }
  )
}

################################################################################
# Private Subnets (Application Tier)
################################################################################

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-private-${var.availability_zones[count.index % length(var.availability_zones)]}"
      Tier = "private"
      Type = "application"
    }
  )
}

################################################################################
# Database Subnets
################################################################################

resource "aws_subnet" "database" {
  count = length(var.database_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.database_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-database-${var.availability_zones[count.index % length(var.availability_zones)]}"
      Tier = "database"
      Type = "database"
    }
  )
}

# Database Subnet Group for RDS
resource "aws_db_subnet_group" "database" {
  name       = "${var.vpc_name}-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-db-subnet-group"
    }
  )
}

################################################################################
# Elastic IPs for NAT Gateways
################################################################################

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : (var.one_nat_gateway_per_az ? length(var.availability_zones) : length(var.public_subnet_cidrs))) : 0

  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-nat-eip-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

################################################################################
# NAT Gateways
################################################################################

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : (var.one_nat_gateway_per_az ? length(var.availability_zones) : length(var.public_subnet_cidrs))) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-nat-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

################################################################################
# Route Tables - Public
################################################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-public-rt"
      Type = "public"
    }
  )
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

################################################################################
# Route Tables - Private
################################################################################

resource "aws_route_table" "private" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_subnet_cidrs)) : 1

  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-private-rt-${count.index + 1}"
      Type = "private"
    }
  )
}

resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? length(aws_route_table.private) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index % length(aws_route_table.private)].id
}

################################################################################
# Route Tables - Database
################################################################################

resource "aws_route_table" "database" {
  count = length(var.database_subnet_cidrs) > 0 ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-database-rt"
      Type = "database"
    }
  )
}

resource "aws_route_table_association" "database" {
  count = length(aws_subnet.database)

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database[0].id
}

################################################################################
# VPC Endpoints - S3 (Gateway Endpoint)
################################################################################

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id
  )

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-s3-endpoint"
    }
  )
}

################################################################################
# VPC Endpoints - DynamoDB (Gateway Endpoint)
################################################################################

resource "aws_vpc_endpoint" "dynamodb" {
  count = var.enable_dynamodb_endpoint ? 1 : 0

  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.dynamodb"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id
  )

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-dynamodb-endpoint"
    }
  )
}

################################################################################
# VPC Flow Logs
################################################################################

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs && var.create_flow_logs_cloudwatch_log_group ? 1 : 0

  name              = "/aws/vpc/${var.vpc_name}/flow-logs"
  retention_in_days = var.flow_logs_retention_in_days

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-flow-logs"
    }
  )
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs && var.create_flow_logs_cloudwatch_iam_role ? 1 : 0

  name = "${var.vpc_name}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs && var.create_flow_logs_cloudwatch_iam_role ? 1 : 0

  name = "${var.vpc_name}-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "main" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-flow-log"
    }
  )
}

################################################################################
# Data Sources
################################################################################

data "aws_region" "current" {}
