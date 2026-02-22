# Azure DevOps Variable Groups Setup Guide

This guide will help you create the required variable groups for the infrastructure pipeline.

## Required Variable Groups

You need to create **2 variable groups** in Azure DevOps:

1. `infrastructure-dev` (for dev environment)
2. `infrastructure-secrets` (for sensitive data)

---

## Step-by-Step Instructions

### 1. Navigate to Variable Groups

1. Go to your Azure DevOps project
2. Click **Pipelines** in the left menu
3. Click **Library**
4. Click **+ Variable group**

---

### 2. Create `infrastructure-dev` Group

**Group Name**: `infrastructure-dev`

**Variables to add**:

| Variable Name | Value | Secret? | Notes |
|--------------|-------|---------|-------|
| `AWS_ACCESS_KEY_ID` | `your-aws-access-key` | ✅ Yes | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | `your-aws-secret-key` | ✅ Yes | Your AWS secret key |
| `AWS_REGION` | `us-east-1` | ❌ No | AWS region |
| `ENVIRONMENT` | `dev` | ❌ No | Environment name |
| `CLUSTER_NAME` | `enterprise-devsecops-dev-eks` | ❌ No | EKS cluster name |
| `LB_CONTROLLER_ROLE_ARN` | `arn:aws:iam::860973283177:role/aws-lb-controller-role` | ❌ No | Will be created by Terraform |
| `CLUSTER_AUTOSCALER_ROLE_ARN` | `arn:aws:iam::860973283177:role/cluster-autoscaler-role` | ❌ No | Will be created by Terraform |

**Steps**:
1. Click **+ Variable group**
2. Enter name: `infrastructure-dev`
3. Add each variable above by clicking **+ Add**
4. For secret variables, click the 🔒 lock icon to mark as secret
5. Click **Save**

---

### 3. Create `infrastructure-secrets` Group

**Group Name**: `infrastructure-secrets`

**Variables to add**:

| Variable Name | Value | Secret? | Notes |
|--------------|-------|---------|-------|
| `COSIGN_PUBLIC_KEY` | `-----BEGIN PUBLIC KEY-----...` | ❌ No | Your Cosign public key |

**To get your Cosign public key**:
```bash
# If you don't have Cosign keys yet, generate them:
cosign generate-key-pair

# Then copy the contents of cosign.pub:
cat cosign.pub
```

**Steps**:
1. Click **+ Variable group**
2. Enter name: `infrastructure-secrets`
3. Add variable: `COSIGN_PUBLIC_KEY`
4. Paste the contents of your `cosign.pub` file
5. Click **Save**

---

### 4. Grant Pipeline Permissions

After creating the variable groups, you need to grant the pipeline permission to use them:

#### Option A: Grant on First Run (Recommended)
1. Run the pipeline
2. It will fail with "not authorized" error
3. Click **Authorize resources** in the error message
4. Approve the access
5. Re-run the pipeline

#### Option B: Grant in Advance
1. In **Pipelines** → **Library**
2. Click on `infrastructure-dev` group
3. Click **Pipeline permissions** tab
4. Click **+** to add pipeline
5. Select your infrastructure pipeline
6. Repeat for `infrastructure-secrets` group

---

## Quick Setup Script

You can also use the Azure CLI to create variable groups:

```bash
# Install Azure DevOps extension
az extension add --name azure-devops

# Login
az login

# Set your organization and project
ORG_URL="https://dev.azure.com/YOUR_ORG"
PROJECT="YOUR_PROJECT"

# Create infrastructure-dev group
az pipelines variable-group create \
  --organization "$ORG_URL" \
  --project "$PROJECT" \
  --name "infrastructure-dev" \
  --variables \
    AWS_REGION=us-east-1 \
    ENVIRONMENT=dev \
    CLUSTER_NAME=enterprise-devsecops-dev-eks

# Add secrets (must be done separately)
az pipelines variable-group variable create \
  --organization "$ORG_URL" \
  --project "$PROJECT" \
  --group-id <GROUP_ID> \
  --name AWS_ACCESS_KEY_ID \
  --value "your-key" \
  --secret true

# Create infrastructure-secrets group
az pipelines variable-group create \
  --organization "$ORG_URL" \
  --project "$PROJECT" \
  --name "infrastructure-secrets" \
  --variables \
    COSIGN_PUBLIC_KEY="$(cat cosign.pub)"
```

---

## Additional Environments

For **staging** or **production**, create additional groups:

- `infrastructure-staging`
- `infrastructure-prod`

Use the same structure as `infrastructure-dev` but with environment-specific values.

---

## Verification

After creating the variable groups:

1. Go to **Pipelines** → **Library**
2. You should see:
   - ✅ `infrastructure-dev`
   - ✅ `infrastructure-secrets`
3. Click on each to verify variables are present
4. Check pipeline permissions are granted

---

## Troubleshooting

### "Variable group was not found"

**Cause**: Variable group doesn't exist

**Solution**: Create the variable groups as described above

---

### "Variable group is not authorized"

**Cause**: Pipeline doesn't have permission to use the variable group

**Solution**: 
1. Run the pipeline
2. Click **Authorize resources** when prompted
3. Or manually grant permissions in Library → Pipeline permissions

---

### "Environment variable is empty"

**Cause**: Pipeline parameter not set

**Solution**: When running the pipeline, select the environment from the dropdown

---

## Next Steps

After creating variable groups:

1. ✅ Commit and push the updated pipeline
2. ✅ Create/edit pipeline in Azure DevOps
3. ✅ Select environment (dev/staging/prod)
4. ✅ Run the pipeline
5. ✅ Authorize variable groups if prompted

---

## Complete Checklist

- [ ] Created `infrastructure-dev` variable group
- [ ] Added all required variables to `infrastructure-dev`
- [ ] Marked secrets (AWS keys) appropriately
- [ ] Created `infrastructure-secrets` variable group
- [ ] Added `COSIGN_PUBLIC_KEY` variable
- [ ] Generated Cosign keys if needed
- [ ] Granted pipeline permissions to both groups
- [ ] Tested pipeline run

---

**Variable Groups Created**: When complete, you should have 2 variable groups ready for the pipeline to use.
