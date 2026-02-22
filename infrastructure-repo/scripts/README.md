# Terraform Backend Setup Scripts

This directory contains scripts to manage the Terraform backend infrastructure.

## Scripts

### create-backend.sh

Creates the required S3 bucket and DynamoDB table for Terraform remote state management.

**Usage:**
```bash
# Create backend for dev environment (default)
./scripts/create-backend.sh

# Create backend for specific environment
./scripts/create-backend.sh prod

# With custom AWS region
AWS_REGION=us-west-2 ./scripts/create-backend.sh prod
```

**What it creates:**
- **S3 Bucket**: `devsecops-terraform-state-{environment}`
  - Versioning enabled
  - AES256 encryption enabled
  - Public access blocked
  - Lifecycle policy (90-day retention for old versions)
  - Logging enabled
  - Tagged appropriately

- **DynamoDB Table**: `terraform-state-lock`
  - Primary key: `LockID` (String)
  - Pay-per-request billing
  - Point-in-time recovery enabled
  - Tagged appropriately

**Prerequisites:**
- AWS CLI installed and configured
- AWS credentials with permissions to create S3 and DynamoDB resources
- Appropriate IAM permissions

### destroy-backend.sh

Destroys the Terraform backend resources (S3 bucket and DynamoDB table).

> [!CAUTION]
> This is a destructive operation that will delete all Terraform state files. Use with extreme caution!

**Usage:**
```bash
# Destroy backend for dev environment (default)
./scripts/destroy-backend.sh

# Destroy backend for specific environment
./scripts/destroy-backend.sh prod
```

The script includes multiple confirmation prompts to prevent accidental deletion.

## Workflow

### Initial Setup

1. **Create backend resources:**
   ```bash
   cd infrastructure-repo
   ./scripts/create-backend.sh dev
   ```

2. **Update backend.tf** (if bucket name is different):
   ```hcl
   terraform {
     backend "s3" {
       bucket         = "devsecops-terraform-state-dev"  # Update if needed
       key            = "eks-infrastructure/terraform.tfstate"
       region         = "us-east-1"
       encrypt        = true
       dynamodb_table = "terraform-state-lock"
     }
   }
   ```

3. **Initialize Terraform:**
   ```bash
   cd terraform
   terraform init
   ```

### Multi-Environment Setup

Create separate backends for each environment:

```bash
# Dev environment
./scripts/create-backend.sh dev

# Staging environment
./scripts/create-backend.sh staging

# Production environment
./scripts/create-backend.sh prod
```

Each environment will have its own S3 bucket: `devsecops-terraform-state-{env}`

## Security Features

### S3 Bucket
- ✅ Server-side encryption (AES256)
- ✅ Versioning enabled (state recovery)
- ✅ Public access blocked
- ✅ Lifecycle policy (automatic cleanup)
- ✅ Bucket logging

### DynamoDB Table
- ✅ State locking (prevents concurrent modifications)
- ✅ Point-in-time recovery
- ✅ Pay-per-request billing (cost-effective)

## Troubleshooting

### Error: "Bucket already exists"
If the bucket name is already taken globally:
1. Choose a different bucket name
2. Update the `BUCKET_NAME` variable in the script
3. Update `backend.tf` accordingly

### Error: "Access Denied"
Ensure your AWS user/role has the following permissions:
- `s3:CreateBucket`
- `s3:PutBucketVersioning`
- `s3:PutBucketEncryption`
- `s3:PutPublicAccessBlock`
- `dynamodb:CreateTable`
- `dynamodb:DescribeTable`

### Checking Backend Status

```bash
# Check S3 bucket
aws s3api head-bucket --bucket devsecops-terraform-state-dev

# Check DynamoDB table
aws dynamodb describe-table --table-name terraform-state-lock
```

## Cost Considerations

- **S3**: Minimal cost for state files (typically < $1/month)
- **DynamoDB**: Pay-per-request, typically < $0.50/month for Terraform locking
- **Total**: Expected cost < $2/month per environment

## Best Practices

1. **Separate environments**: Use different backends for dev/staging/prod
2. **Version control**: Keep backend.tf in Git, but never commit state files
3. **Access control**: Restrict S3 bucket access using IAM policies
4. **Backup**: S3 versioning provides automatic backups
5. **Monitoring**: Set up CloudWatch alarms for unauthorized access

## Migration

If you need to migrate from local state to remote backend:

```bash
# After creating backend
terraform init -migrate-state

# Terraform will ask to confirm migration
# Type 'yes' to migrate local state to S3
```

## References

- [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [DynamoDB for Terraform State Locking](https://developer.hashicorp.com/terraform/language/settings/backends/s3#dynamodb-state-locking)
