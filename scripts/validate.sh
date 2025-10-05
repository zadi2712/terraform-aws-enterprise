#!/bin/bash
################################################################################
# Infrastructure Validation Script
# Description: Validate deployed infrastructure
################################################################################

set -e

ENVIRONMENT=${1:-dev}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Infrastructure Validation - $ENVIRONMENT${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Function to check a resource
check_resource() {
    local resource=$1
    local command=$2
    local expected=$3
    
    echo -n "Checking $resource... "
    if output=$(eval "$command" 2>/dev/null); then
        if [ -n "$expected" ] && [ "$output" != "$expected" ]; then
            echo -e "${YELLOW}⚠️  Warning: Unexpected result${NC}"
            return 1
        fi
        echo -e "${GREEN}✅${NC}"
        return 0
    else
        echo -e "${RED}❌${NC}"
        return 1
    fi
}

PASSED=0
FAILED=0

# Check VPC
echo -e "${BLUE}Networking Layer:${NC}"
if check_resource "VPC" \
    "aws ec2 describe-vpcs --filters Name=tag:Environment,Values=$ENVIRONMENT --query 'Vpcs[0].VpcId' --output text"; then
    VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Environment,Values=$ENVIRONMENT --query 'Vpcs[0].VpcId' --output text)
    echo "  VPC ID: $VPC_ID"
    ((PASSED++))
else
    ((FAILED++))
fi

# Check Subnets
if check_resource "Subnets" \
    "aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID --query 'length(Subnets)'"; then
    SUBNET_COUNT=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID --query 'length(Subnets)' --output text)
    echo "  Subnet count: $SUBNET_COUNT"
    ((PASSED++))
else
    ((FAILED++))
fi

# Check NAT Gateways
if check_resource "NAT Gateways" \
    "aws ec2 describe-nat-gateways --filter Name=vpc-id,Values=$VPC_ID Name=state,Values=available --query 'length(NatGateways)'"; then
    NAT_COUNT=$(aws ec2 describe-nat-gateways --filter Name=vpc-id,Values=$VPC_ID Name=state,Values=available --query 'length(NatGateways)' --output text)
    echo "  NAT Gateway count: $NAT_COUNT"
    ((PASSED++))
else
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}Compute Layer:${NC}"

# Check ECS Clusters
if check_resource "ECS Clusters" \
    "aws ecs list-clusters --query 'length(clusterArns)'"; then
    CLUSTER_COUNT=$(aws ecs list-clusters --query 'length(clusterArns)' --output text)
    echo "  ECS Cluster count: $CLUSTER_COUNT"
    ((PASSED++))
else
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}Database Layer:${NC}"

# Check RDS Instances
if check_resource "RDS Instances" \
    "aws rds describe-db-instances --query 'length(DBInstances)'"; then
    RDS_COUNT=$(aws rds describe-db-instances --query 'length(DBInstances)' --output text)
    echo "  RDS Instance count: $RDS_COUNT"
    ((PASSED++))
else
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}Storage Layer:${NC}"

# Check S3 Buckets
if check_resource "S3 Buckets" \
    "aws s3 ls | grep $ENVIRONMENT | wc -l"; then
    BUCKET_COUNT=$(aws s3 ls | grep "$ENVIRONMENT" | wc -l | tr -d ' ')
    echo "  S3 Bucket count: $BUCKET_COUNT"
    ((PASSED++))
else
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}Security Layer:${NC}"

# Check KMS Keys
if check_resource "KMS Keys" \
    "aws kms list-keys --query 'length(Keys)'"; then
    ((PASSED++))
else
    ((FAILED++))
fi

# Check Security Groups
if check_resource "Security Groups" \
    "aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC_ID --query 'length(SecurityGroups)'"; then
    SG_COUNT=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC_ID --query 'length(SecurityGroups)' --output text)
    echo "  Security Group count: $SG_COUNT"
    ((PASSED++))
else
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Validation Summary${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""
echo -e "${GREEN}Passed: $PASSED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED${NC}"
    echo ""
    echo -e "${RED}❌ Validation failed${NC}"
    exit 1
else
    echo -e "${RED}Failed: $FAILED${NC}"
    echo ""
    echo -e "${GREEN}✅ All checks passed!${NC}"
fi

echo ""
echo "💡 For detailed resource information, run:"
echo "   aws ec2 describe-vpcs --filters Name=tag:Environment,Values=$ENVIRONMENT"
echo "   aws ecs list-clusters"
echo "   aws rds describe-db-instances"
