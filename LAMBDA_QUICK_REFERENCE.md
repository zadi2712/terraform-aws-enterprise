# Lambda Quick Reference

## 🚀 Quick Start

### Create and Deploy Function

```bash
# 1. Create function code
cat > index.py << 'EOF'
def handler(event, context):
    return {'statusCode': 200, 'body': 'Hello!'}
EOF

# 2. Package
zip lambda.zip index.py

# 3. Deploy with Terraform
# (configure module in your terraform files)
terraform apply

# 4. Test
aws lambda invoke \
  --function-name my-function \
  --payload '{}' \
  response.json && cat response.json
```

---

## 📋 Common Commands

### Invoke Function

```bash
# Synchronous
aws lambda invoke \
  --function-name my-function \
  --payload '{"key":"value"}' \
  response.json

# Asynchronous
aws lambda invoke \
  --function-name my-function \
  --invocation-type Event \
  --payload '{"key":"value"}' \
  response.json

# Dry run (validate)
aws lambda invoke \
  --function-name my-function \
  --invocation-type DryRun \
  --payload '{}' \
  response.json
```

### View Logs

```bash
# Tail logs
aws logs tail /aws/lambda/my-function --follow

# View recent logs
aws logs tail /aws/lambda/my-function --since 1h

# Filter logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/my-function \
  --filter-pattern "ERROR"
```

### Function Management

```bash
# Get function config
aws lambda get-function --function-name my-function

# Update function code
aws lambda update-function-code \
  --function-name my-function \
  --zip-file fileb://lambda.zip

# Update configuration
aws lambda update-function-configuration \
  --function-name my-function \
  --timeout 60 \
  --memory-size 512

# Delete function
aws lambda delete-function --function-name my-function
```

---

## 🎯 Configuration Templates

### Basic Function

```hcl
module "basic" {
  source = "../../modules/lambda"

  function_name = "hello"
  filename      = "lambda.zip"
  handler       = "index.handler"
  runtime       = "python3.11"
  
  memory_size = 128
  timeout     = 3
}
```

### Production Function

```hcl
module "prod" {
  source = "../../modules/lambda"

  function_name = "api-prod"
  s3_bucket     = "deployments"
  s3_key        = "api/v1.0.0.zip"
  handler       = "index.handler"
  runtime       = "python3.11"
  architectures = ["arm64"]  # 20% savings

  memory_size = 512
  timeout     = 30

  vpc_config = {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  create_role = true
  tracing_mode = "Active"
  log_retention_days = 30
  
  publish = true
  aliases = {
    live = { function_version = "1" }
  }
}
```

---

## ⚡ Performance Tips

### Memory Allocation

| Memory (MB) | vCPU | Use Case |
|-------------|------|----------|
| 128 | 0.08 | Simple tasks |
| 512 | 0.3 | API handlers |
| 1769 | 1.0 | CPU-intensive |
| 3008 | 1.8 | ML inference |

### Benchmarking

```bash
# Use Lambda Power Tuning
# https://github.com/alexcasalboni/aws-lambda-power-tuning
```

---

## 💰 Cost Calculator

```python
# requests/month * duration(s) * memory(GB)

# Example: 1M requests, 200ms, 128MB
requests = 1_000_000
duration = 0.2  # seconds
memory_gb = 0.125

compute_cost = requests * duration * memory_gb * 0.0000166667
request_cost = (requests / 1_000_000) * 0.20

total = compute_cost + request_cost
# ≈ $5.17/month
```

---

## 🔍 Monitoring

### CloudWatch Metrics

```bash
# Invocations
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=my-function \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

# Errors
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=my-function \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

# Duration
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=my-function \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

---

## 🚨 Troubleshooting

### Function Errors

```bash
# Check recent errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/my-function \
  --filter-pattern "ERROR" \
  --start-time $(date -u -d '1 hour ago' +%s)000

# Get function configuration
aws lambda get-function-configuration \
  --function-name my-function
```

### Timeout Issues

```bash
# Increase timeout
terraform apply -var="timeout=60"

# Or optimize code
# Or increase memory (more CPU)
```

### VPC Issues

```bash
# Check ENI creation
aws ec2 describe-network-interfaces \
  --filters "Name=description,Values=AWS Lambda VPC ENI*"

# Verify NAT Gateway
aws ec2 describe-nat-gateways

# Check VPC endpoints
aws ec2 describe-vpc-endpoints
```

---

## 📚 Additional Resources

- [Lambda Module README](modules/lambda/README.md)
- [Lambda Deployment Guide](LAMBDA_DEPLOYMENT_GUIDE.md)
- [AWS Lambda Pricing Calculator](https://aws.amazon.com/lambda/pricing/)

---

**Lambda Quick Reference v2.0**

