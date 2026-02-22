#!/bin/bash
# Script to create Terraform backend resources (S3 + DynamoDB)
# This must be run before initializing Terraform

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${1:-dev}"

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

BUCKET_NAME="devsecops-tfstate-${ACCOUNT_ID}-${ENVIRONMENT}"
DYNAMODB_TABLE="terraform-state-lock"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Terraform Backend Setup${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "Environment: ${ENVIRONMENT}"
echo "Region: ${REGION}"
echo "S3 Bucket: ${BUCKET_NAME}"
echo "DynamoDB Table: ${DYNAMODB_TABLE}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials are not configured${NC}"
    echo "Please configure AWS credentials using 'aws configure'"
    exit 1
fi

echo -e "${GREEN}✓ AWS CLI configured${NC}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account: ${ACCOUNT_ID}"
echo ""

# ============================================
# Create S3 Bucket
# ============================================
echo -e "${YELLOW}Creating S3 bucket...${NC}"

# Check if bucket exists
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Bucket ${BUCKET_NAME} already exists${NC}"
else
    # Create bucket
    if [ "${REGION}" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${REGION}"
    else
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${REGION}" \
            --create-bucket-configuration LocationConstraint="${REGION}"
    fi
    echo -e "${GREEN}✓ S3 bucket created: ${BUCKET_NAME}${NC}"
fi

# Enable versioning
echo "Enabling versioning..."
aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled
echo -e "${GREEN}✓ Versioning enabled${NC}"

# Enable encryption
echo "Enabling encryption..."
aws s3api put-bucket-encryption \
    --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }
        ]
    }'
echo -e "${GREEN}✓ Encryption enabled (AES256)${NC}"

# Block public access
echo "Blocking public access..."
aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
echo -e "${GREEN}✓ Public access blocked${NC}"

# Enable bucket logging (optional but recommended)
echo "Configuring bucket logging..."
aws s3api put-bucket-logging \
    --bucket "${BUCKET_NAME}" \
    --bucket-logging-status '{
        "LoggingEnabled": {
            "TargetBucket": "'"${BUCKET_NAME}"'",
            "TargetPrefix": "logs/"
        }
    }' 2>/dev/null || echo -e "${YELLOW}⚠ Could not enable logging (may require additional setup)${NC}"

# Add lifecycle policy to clean up old versions
echo "Adding lifecycle policy..."
aws s3api put-bucket-lifecycle-configuration \
    --bucket "${BUCKET_NAME}" \
    --lifecycle-configuration '{
        "Rules": [
            {
                "ID": "DeleteOldVersions",
                "Status": "Enabled",
                "NoncurrentVersionExpiration": {
                    "NoncurrentDays": 90
                }
            },
            {
                "ID": "AbortIncompleteMultipartUploads",
                "Status": "Enabled",
                "AbortIncompleteMultipartUpload": {
                    "DaysAfterInitiation": 7
                },
                "Filter": {
                    "Prefix": ""
                }
            }
        ]
    }' 2>&1 || echo "⚠ Lifecycle policy may already be configured"
echo -e "${GREEN}✓ Lifecycle policy configured${NC}"

# Add bucket tags
echo "Adding tags..."
aws s3api put-bucket-tagging \
    --bucket "${BUCKET_NAME}" \
    --tagging 'TagSet=[
        {Key=Purpose,Value=TerraformState},
        {Key=Environment,Value='"${ENVIRONMENT}"'},
        {Key=ManagedBy,Value=Script},
        {Key=Project,Value=Enterprise-DevSecOps}
    ]'
echo -e "${GREEN}✓ Tags added${NC}"

echo ""

# ============================================
# Create DynamoDB Table
# ============================================
echo -e "${YELLOW}Creating DynamoDB table...${NC}"

# Check if table exists
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${REGION}" &> /dev/null; then
    echo -e "${YELLOW}⚠ DynamoDB table ${DYNAMODB_TABLE} already exists${NC}"
else
    # Create table
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${REGION}" \
        --tags Key=Purpose,Value=TerraformLock \
              Key=Environment,Value="${ENVIRONMENT}" \
              Key=ManagedBy,Value=Script \
              Key=Project,Value=Enterprise-DevSecOps
    
    echo -e "${GREEN}✓ DynamoDB table created: ${DYNAMODB_TABLE}${NC}"
    
    # Wait for table to be active
    echo "Waiting for table to become active..."
    aws dynamodb wait table-exists \
        --table-name "${DYNAMODB_TABLE}" \
        --region "${REGION}"
    echo -e "${GREEN}✓ Table is active${NC}"
fi

# Enable point-in-time recovery
echo "Enabling point-in-time recovery..."
aws dynamodb update-continuous-backups \
    --table-name "${DYNAMODB_TABLE}" \
    --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
    --region "${REGION}" 2>/dev/null || echo -e "${YELLOW}⚠ Could not enable point-in-time recovery${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Backend setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Backend Configuration:"
echo "  S3 Bucket:       ${BUCKET_NAME}"
echo "  DynamoDB Table:  ${DYNAMODB_TABLE}"
echo "  Region:          ${REGION}"
echo ""
echo "Next steps:"
echo "1. Update backend.tf with the correct bucket name"
echo "2. Run: terraform init"
echo "3. Run: terraform plan"
echo ""
echo "Backend configuration example for backend.tf:"
echo ""
echo "terraform {"
echo "  backend \"s3\" {"
echo "    bucket         = \"${BUCKET_NAME}\""
echo "    key            = \"eks-infrastructure/terraform.tfstate\""
echo "    region         = \"${REGION}\""
echo "    encrypt        = true"
echo "    dynamodb_table = \"${DYNAMODB_TABLE}\""
echo "  }"
echo "}"
echo ""
