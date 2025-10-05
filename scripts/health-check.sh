#!/bin/bash
################################################################################
# Health Check Script - Verify infrastructure health
################################################################################

set -e

ENV=${1:-dev}
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Health Check for Environment: ${ENV}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Set AWS profile if exists
export AWS_PROFILE=${ENV}

# Check VPC
echo -e "${YELLOW}1. Checking VPC...${NC}"
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Environment,Values=${ENV}" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null)

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    echo -e "  ${GREEN}✓ VPC exists: ${VPC_ID}${NC}"
else
    echo -e "  ${RED}✗ VPC not found${NC}"
fi

# Check Subnets
echo -e "${YELLOW}2. Checking Subnets...${NC}"
SUBNET_COUNT=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'length(Subnets)' \
    --output text 2>/dev/null)

if [ "$SUBNET_COUNT" -gt 0 ] 2>/dev/null; then
    echo -e "  ${GREEN}✓ Found ${SUBNET_COUNT} subnets${NC}"
else
    echo -e "  ${RED}✗ No subnets found${NC}"
fi

# Check NAT Gateways
echo -e "${YELLOW}3. Checking NAT Gateways...${NC}"
NAT_COUNT=$(aws ec2 describe-nat-gateways \
    --filter "Name=vpc-id,Values=${VPC_ID}" "Name=state,Values=available" \
    --query 'length(NatGateways)' \
    --output text 2>/dev/null)

if [ "$NAT_COUNT" -gt 0 ] 2>/dev/null; then
    echo -e "  ${GREEN}✓ ${NAT_COUNT} NAT Gateway(s) available${NC}"
else
    echo -e "  ${YELLOW}⚠ No NAT Gateways found${NC}"
fi

# Check RDS Instances
echo -e "${YELLOW}4. Checking RDS Instances...${NC}"
RDS_COUNT=$(aws rds describe-db-instances \
    --query 'length(DBInstances)' \
    --output text 2>/dev/null)

if [ "$RDS_COUNT" -gt 0 ] 2>/dev/null; then
    echo -e "  ${GREEN}✓ Found ${RDS_COUNT} RDS instance(s)${NC}"
    aws rds describe-db-instances \
        --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus]' \
        --output table 2>/dev/null
else
    echo -e "  ${YELLOW}⚠ No RDS instances found${NC}"
fi

# Check ECS Clusters
echo -e "${YELLOW}5. Checking ECS Clusters...${NC}"
ECS_COUNT=$(aws ecs list-clusters \
    --query 'length(clusterArns)' \
    --output text 2>/dev/null)

if [ "$ECS_COUNT" -gt 0 ] 2>/dev/null; then
    echo -e "  ${GREEN}✓ Found ${ECS_COUNT} ECS cluster(s)${NC}"
else
    echo -e "  ${YELLOW}⚠ No ECS clusters found${NC}"
fi

# Check S3 Buckets
echo -e "${YELLOW}6. Checking S3 Buckets...${NC}"
S3_BUCKETS=$(aws s3 ls | grep "${ENV}" | wc -l)

if [ "$S3_BUCKETS" -gt 0 ]; then
    echo -e "  ${GREEN}✓ Found ${S3_BUCKETS} S3 bucket(s)${NC}"
else
    echo -e "  ${YELLOW}⚠ No S3 buckets found with environment tag${NC}"
fi

# Check CloudWatch Alarms
echo -e "${YELLOW}7. Checking CloudWatch Alarms...${NC}"
ALARM_COUNT=$(aws cloudwatch describe-alarms \
    --state-value ALARM \
    --query 'length(MetricAlarms)' \
    --output text 2>/dev/null)

if [ "$ALARM_COUNT" -eq 0 ] 2>/dev/null; then
    echo -e "  ${GREEN}✓ No active alarms${NC}"
else
    echo -e "  ${RED}✗ ${ALARM_COUNT} alarm(s) in ALARM state:${NC}"
    aws cloudwatch describe-alarms \
        --state-value ALARM \
        --query 'MetricAlarms[*].[AlarmName,StateReason]' \
        --output table 2>/dev/null
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Health Check Complete${NC}"
echo -e "${GREEN}========================================${NC}"
