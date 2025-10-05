#!/bin/bash
################################################################################
# Backend Setup Script
# Description: Create S3 bucket and DynamoDB table for Terraform state
################################################################################

set -e

ENVIRONMENT=${1:-dev}
AWS_REGION=${2:-us-east-1}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "🚀 Setting up Terraform backend for $ENVIRONMENT"
echo "   AWS Account: $AWS_ACCOUNT_ID"
echo "   Region: $AWS_REGION"
echo ""

BUCKET_NAME="terraform-state-${ENVIRONMENT}-${AWS_ACCOUNT_ID}"
TABLE_NAME="terraform-state-lock-${ENVIRONMENT}"

# Create S3 bucket
echo "📦 Creating S3 bucket: $BUCKET_NAME"
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "   ✅ Bucket already exists"
else
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION" 2>/dev/null || \
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region us-east-1
    echo "   ✅ Bucket created"
fi

# Enable versioning
echo "📝 Enabling versioning..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled
echo "   ✅ Versioning enabled"

# Enable encryption
echo "🔒 Enabling encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'
echo "   ✅ Encryption enabled"

# Block public access
echo "🛡️  Blocking public access..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
echo "   ✅ Public access blocked"

# Create DynamoDB table
echo "🗄️  Creating DynamoDB table: $TABLE_NAME"
if aws dynamodb describe-table --table-name "$TABLE_NAME" 2>/dev/null; then
    echo "   ✅ Table already exists"
else
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --tags Key=Environment,Value="$ENVIRONMENT" Key=ManagedBy,Value=terraform
    echo "   ✅ Table created"
    
    # Wait for table to be active
    echo "   ⏳ Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "$TABLE_NAME"
    echo "   ✅ Table is active"
fi

echo ""
echo "✅ Backend setup complete!"
echo ""
echo "📋 Configuration:"
echo "   Bucket: $BUCKET_NAME"
echo "   Table: $TABLE_NAME"
echo "   Region: $AWS_REGION"
echo ""
echo "💡 Next steps:"
echo "   1. Update backend.conf files with your account ID"
echo "   2. Run: terraform init -backend-config=backend.conf"
