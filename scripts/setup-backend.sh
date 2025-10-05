#!/bin/bash
################################################################################
# Setup Backend - Create S3 buckets and DynamoDB tables for Terraform state
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Terraform Backend Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}Error: Unable to get AWS Account ID. Check your AWS credentials.${NC}"
    exit 1
fi

echo -e "${YELLOW}AWS Account ID: ${AWS_ACCOUNT_ID}${NC}"
echo ""

# Environments
ENVIRONMENTS=("dev" "qa" "uat" "prod")
AWS_REGION="us-east-1"

for ENV in "${ENVIRONMENTS[@]}"; do
    echo -e "${GREEN}Setting up backend for environment: ${ENV}${NC}"
    
    BUCKET_NAME="terraform-state-${ENV}-${AWS_ACCOUNT_ID}"
    TABLE_NAME="terraform-state-lock-${ENV}"
    
    # Create S3 bucket
    echo "  Creating S3 bucket: ${BUCKET_NAME}"
    if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
        echo -e "  ${YELLOW}Bucket already exists${NC}"
    else
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${AWS_REGION}" \
            --profile "${ENV}" 2>/dev/null || \
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${AWS_REGION}"
        echo -e "  ${GREEN}✓ Bucket created${NC}"
    fi
    
    # Enable versioning
    echo "  Enabling versioning"
    aws s3api put-bucket-versioning \
        --bucket "${BUCKET_NAME}" \
        --versioning-configuration Status=Enabled \
        --profile "${ENV}" 2>/dev/null || \
    aws s3api put-bucket-versioning \
        --bucket "${BUCKET_NAME}" \
        --versioning-configuration Status=Enabled
    echo -e "  ${GREEN}✓ Versioning enabled${NC}"
    
    # Enable encryption
    echo "  Enabling encryption"
    aws s3api put-bucket-encryption \
        --bucket "${BUCKET_NAME}" \
        --server-side-encryption-configuration \
        '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}' \
        --profile "${ENV}" 2>/dev/null || \
    aws s3api put-bucket-encryption \
        --bucket "${BUCKET_NAME}" \
        --server-side-encryption-configuration \
        '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'
    echo -e "  ${GREEN}✓ Encryption enabled${NC}"
    
    # Block public access
    echo "  Blocking public access"
    aws s3api put-public-access-block \
        --bucket "${BUCKET_NAME}" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
        --profile "${ENV}" 2>/dev/null || \
    aws s3api put-public-access-block \
        --bucket "${BUCKET_NAME}" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    echo -e "  ${GREEN}✓ Public access blocked${NC}"
    
    # Create DynamoDB table
    echo "  Creating DynamoDB table: ${TABLE_NAME}"
    if aws dynamodb describe-table --table-name "${TABLE_NAME}" --profile "${ENV}" 2>/dev/null || \
       aws dynamodb describe-table --table-name "${TABLE_NAME}" 2>/dev/null; then
        echo -e "  ${YELLOW}Table already exists${NC}"
    else
        aws dynamodb create-table \
            --table-name "${TABLE_NAME}" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST \
            --tags Key=Environment,Value="${ENV}" Key=ManagedBy,Value=terraform \
            --profile "${ENV}" 2>/dev/null || \
        aws dynamodb create-table \
            --table-name "${TABLE_NAME}" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST \
            --tags Key=Environment,Value="${ENV}" Key=ManagedBy,Value=terraform
        echo -e "  ${GREEN}✓ DynamoDB table created${NC}"
        
        # Wait for table to be active
        echo "  Waiting for table to be active..."
        aws dynamodb wait table-exists --table-name "${TABLE_NAME}" --profile "${ENV}" 2>/dev/null || \
        aws dynamodb wait table-exists --table-name "${TABLE_NAME}"
        echo -e "  ${GREEN}✓ Table is active${NC}"
    fi
    
    echo ""
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Backend setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Update backend.conf files with your AWS Account ID"
echo "2. Run 'make init ENV=dev LAYER=networking' to initialize Terraform"
echo "3. Run 'make plan ENV=dev LAYER=networking' to create an execution plan"
