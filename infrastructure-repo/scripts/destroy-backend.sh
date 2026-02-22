#!/bin/bash
# Script to destroy Terraform backend resources (S3 + DynamoDB)
# WARNING: This will delete the S3 bucket and all Terraform state files!
# Use with extreme caution, preferably only in dev/test environments

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${1:-dev}"

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")

BUCKET_NAME="devsecops-tfstate-${ACCOUNT_ID}-${ENVIRONMENT}"
DYNAMODB_TABLE="terraform-state-lock"

echo -e "${RED}========================================${NC}"
echo -e "${RED}WARNING: DESTRUCTIVE OPERATION${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo "This will DELETE:"
echo "  - S3 Bucket: ${BUCKET_NAME} (and ALL state files)"
echo "  - DynamoDB Table: ${DYNAMODB_TABLE}"
echo "  - Region: ${REGION}"
echo ""
echo -e "${YELLOW}This action CANNOT be undone!${NC}"
echo ""

# Confirmation prompt
read -p "Are you sure you want to continue? (type 'yes' to confirm): " -r
echo
if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Second confirmation
echo -e "${RED}FINAL WARNING: All Terraform state will be lost!${NC}"
read -p "Type the environment name '${ENVIRONMENT}' to confirm: " -r
echo
if [[ $REPLY != "${ENVIRONMENT}" ]]; then
    echo "Confirmation failed. Operation cancelled."
    exit 0
fi

echo ""
echo "Destroying backend resources..."
echo ""

# Delete S3 bucket (including all objects and versions)
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    echo "Deleting S3 bucket and all contents..."
    aws s3 rb "s3://${BUCKET_NAME}" --force
    echo -e "✓ S3 bucket deleted"
else
    echo "⚠ Bucket ${BUCKET_NAME} does not exist"
fi

# Delete DynamoDB table
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${REGION}" &> /dev/null; then
    echo "Deleting DynamoDB table..."
    aws dynamodb delete-table \
        --table-name "${DYNAMODB_TABLE}" \
        --region "${REGION}" > /dev/null
    echo -e "✓ DynamoDB table deleted"
else
    echo "⚠ DynamoDB table ${DYNAMODB_TABLE} does not exist"
fi

echo ""
echo -e "✓ Backend resources destroyed"
echo ""
