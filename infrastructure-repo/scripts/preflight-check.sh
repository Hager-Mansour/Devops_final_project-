#!/bin/bash
# Pre-Flight Validation Script
# Run this before deploying infrastructure to catch issues early

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ISSUES_FOUND=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Infrastructure Pre-Flight Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

command -v aws >/dev/null 2>&1 || { echo -e "${RED}✗ AWS CLI not installed${NC}"; ISSUES_FOUND=$((ISSUES_FOUND+1)); }
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}✗ Terraform not installed${NC}"; ISSUES_FOUND=$((ISSUES_FOUND+1)); }
command -v ansible >/dev/null 2>&1 || { echo -e "${RED}✗ Ansible not installed${NC}"; ISSUES_FOUND=$((ISSUES_FOUND+1)); }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}✗ kubectl not installed${NC}"; ISSUES_FOUND=$((ISSUES_FOUND+1)); }

if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}✓ All prerequisites installed${NC}"
else
    echo -e "${RED}✗ Missing prerequisites: $ISSUES_FOUND${NC}"
fi

echo ""

# Check AWS credentials
echo -e "${YELLOW}Checking AWS credentials...${NC}"
if aws sts get-caller-identity >/dev/null 2>&1; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo -e "${GREEN}✓ AWS credentials configured (Account: $ACCOUNT_ID)${NC}"
else
    echo -e "${RED}✗ AWS credentials not configured${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
fi

echo ""

# Check Terraform
echo -e "${YELLOW}Validating Terraform...${NC}"

cd terraform 2>/dev/null || { echo -e "${RED}✗ terraform/ directory not found${NC}"; exit 1; }

# Check formatting
if terraform fmt -check -recursive >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Terraform formatting valid${NC}"
else
    echo -e "${YELLOW}⚠ Terraform formatting issues (run 'terraform fmt')${NC}"
fi

# Check if using remote modules (from main.tf)
if grep -q 'source.*terraform-aws-modules' main.tf 2>/dev/null; then
    echo -e "${GREEN}✓ Using official Terraform AWS modules${NC}"
elif [ -d "modules" ]; then
    echo -e "${GREEN}✓ Terraform modules directory exists${NC}"
else
    echo -e "${YELLOW}⚠ No modules directory found (will be downloaded from registry)${NC}"
fi

# Check backend configuration
if grep -q '\${var\.' backend.tf 2>/dev/null; then
    echo -e "${RED}✗ backend.tf contains variable interpolation (not supported)${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
else
    echo -e "${GREEN}✓ backend.tf configuration valid${NC}"
fi

# Try terraform validate
# Initialize without backend first to download modules
echo -e "${YELLOW}Initializing Terraform modules...${NC}"
terraform init -backend=false >/dev/null 2>&1

if terraform validate >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Terraform configuration valid${NC}"
else
    echo -e "${RED}✗ Terraform configuration invalid (run 'terraform validate' for details)${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
fi

cd ..

echo ""

# Check Ansible
echo -e "${YELLOW}Validating Ansible...${NC}"

cd ansible 2>/dev/null || { echo -e "${RED}✗ ansible/ directory not found${NC}"; exit 1; }

PLAYBOOK_COUNT=0
PLAYBOOK_ERRORS=0

for playbook in playbooks/*.yml; do
    if [ -f "$playbook" ]; then
        PLAYBOOK_COUNT=$((PLAYBOOK_COUNT+1))
        if ansible-playbook "$playbook" --syntax-check >/dev/null 2>&1; then
            echo -e "${GREEN}✓ $(basename $playbook)${NC}"
        else
            echo -e "${RED}✗ $(basename $playbook)${NC}"
            PLAYBOOK_ERRORS=$((PLAYBOOK_ERRORS+1))
            ISSUES_FOUND=$((ISSUES_FOUND+1))
        fi
    fi
done

if [ $PLAYBOOK_ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All $PLAYBOOK_COUNT playbooks validated${NC}"
fi

cd ..

echo ""

# Check environment variables
echo -e "${YELLOW}Checking required environment variables...${NC}"

ENV_ISSUES=0

[ -z "$CLUSTER_NAME" ] && echo -e "${YELLOW}⚠ CLUSTER_NAME not set${NC}" && ENV_ISSUES=1
[ -z "$COSIGN_PUBLIC_KEY" ] && echo -e "${YELLOW}⚠ COSIGN_PUBLIC_KEY not set${NC}" && ENV_ISSUES=1

if [ $ENV_ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ Required environment variables set${NC}"
else
    echo -e "${YELLOW}⚠ Some environment variables missing (required for Ansible)${NC}"
fi

echo ""

# Check backend resources
echo -e "${YELLOW}Checking Terraform backend resources...${NC}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")
BUCKET_NAME="devsecops-tfstate-${ACCOUNT_ID}-${TF_VAR_environment:-dev}"

if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "${GREEN}✓ S3 backend bucket exists: $BUCKET_NAME${NC}"
else
    echo -e "${RED}✗ S3 backend bucket does not exist${NC}"
    echo -e "  ${YELLOW}Run: ./scripts/create-backend.sh${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
fi

if aws dynamodb describe-table --table-name terraform-state-lock >/dev/null 2>&1; then
    echo -e "${GREEN}✓ DynamoDB state lock table exists${NC}"
else
    echo -e "${RED}✗ DynamoDB state lock table does not exist${NC}"
    echo -e "  ${YELLOW}Run: ./scripts/create-backend.sh${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
fi

echo ""
echo -e "${BLUE}========================================${NC}"

if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}✓ PRE-FLIGHT CHECK PASSED${NC}"
    echo -e "${GREEN}  No critical issues found${NC}"
    echo -e "${GREEN}  Ready for deployment!${NC}"
    exit 0
else
    echo -e "${RED}✗ PRE-FLIGHT CHECK FAILED${NC}"
    echo -e "${RED}  Found $ISSUES_FOUND issue(s)${NC}"
    echo -e "${YELLOW}  Review issues above before deployment${NC}"
    echo ""
    echo -e "For detailed validation report, see:"
    echo -e "  ${BLUE}validation_report.md${NC}"
    exit 1
fi
