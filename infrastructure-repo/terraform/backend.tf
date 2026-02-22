terraform {
  backend "s3" {
    # Bucket name format: devsecops-tfstate-{ACCOUNT_ID}-{ENVIRONMENT}
    # Update this with your AWS account ID and environment
    # Or use -backend-config flag: terraform init -backend-config="bucket=devsecops-tfstate-860973283177-dev"
    bucket         = "devsecops-tfstate-860973283177-dev" # TODO: Update with your account ID
    key            = "eks-infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"

    # Enable versioning for state file recovery
    # Enable server-side encryption
    # Block public access
  }

  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# Note: Before using this backend, you must create:
# 1. S3 bucket with versioning and encryption enabled
# 2. DynamoDB table with 'LockID' as the primary key (String type)
#
# Run the script: scripts/create-backend.sh
