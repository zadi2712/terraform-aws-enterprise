################################################################################
# VPC Module - Outputs
################################################################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.main.arn
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "List of database subnet IDs"
  value       = aws_subnet.database[*].id
}

output "database_subnet_group_name" {
  description = "Name of the database subnet group"
  value       = aws_db_subnet_group.database.name
}

output "public_route_table_ids" {
  description = "List of public route table IDs"
  value       = [aws_route_table.public.id]
}

output "private_route_table_ids" {
  description = "List of private route table IDs"
  value       = aws_route_table.private[*].id
}

output "vpc_endpoint_s3_id" {
  description = "ID of S3 VPC endpoint"
  value       = var.enable_s3_endpoint ? aws_vpc_endpoint.s3[0].id : null
}

output "vpc_endpoint_dynamodb_id" {
  description = "ID of DynamoDB VPC endpoint"
  value       = var.enable_dynamodb_endpoint ? aws_vpc_endpoint.dynamodb[0].id : null
}

output "vpc_flow_log_id" {
  description = "ID of VPC Flow Log"
  value       = var.enable_flow_logs ? aws_flow_log.main[0].id : null
}

output "vpc_flow_log_cloudwatch_log_group_name" {
  description = "Name of CloudWatch Log Group for Flow Logs"
  value       = var.enable_flow_logs && var.create_flow_logs_cloudwatch_log_group ? aws_cloudwatch_log_group.flow_logs[0].name : null
}
