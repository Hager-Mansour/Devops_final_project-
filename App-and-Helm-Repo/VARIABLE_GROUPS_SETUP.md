# Azure DevOps Variable Groups Setup

## Required Variable Groups

Create these 4 variable groups in Azure DevOps before running pipelines.

## 1. AWS-Credentials

**Purpose**: AWS authentication for ECR and EKS access

| Variable Name           | Value               | Secret? |
| ----------------------- | ------------------- | ------- |
| `AWS_ACCESS_KEY_ID`     | Your AWS access key | No      |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key | **Yes** |
| `AWS_REGION`            | `us-east-1`         | No      |
| `AWS_ACCOUNT_ID`        | `860973283177`      | No      |

### How to Create
```bash
# Azure DevOps UI:
# Project Settings → Pipelines → Library → + Variable group
# Name: AWS-Credentials

# Add each variable above
# Check "Keep this value secret" for AWS_SECRET_ACCESS_KEY
```

## 2. Docker-Registry

**Purpose**: ECR registry and repository names

| Variable Name   | Value                                          | Secret? |
| --------------- | ---------------------------------------------- | ------- |
| `ECR_REGISTRY`  | `860973283177.dkr.ecr.us-east-1.amazonaws.com` | No      |
| `FRONTEND_REPO` | `devsecops-dev-frontend`                       | No      |
| `BACKEND_REPO`  | `devsecops-dev-backend`                        | No      |

## 3. Cosign-Keys

**Purpose**: Image signing with Cosign

| Variable Name        | Value                  | Secret? |
| -------------------- | ---------------------- | ------- |
| `COSIGN_PRIVATE_KEY` | Paste full private key | **Yes** |
| `COSIGN_PUBLIC_KEY`  | Paste full public key  | No      |
| `COSIGN_PASSWORD`    | Key password           | **Yes** |

### Getting Cosign Keys

If you already generated keys in the infrastructure repo:
```bash
# From infrastructure-repo/
cat cosign.key
cat cosign.pub

# Paste the full content (including BEGIN/END lines)
```

If you need to generate new keys (!):
```bash
cosign generate-key-pair

# Enter password when prompted
# Copy cosign.key → COSIGN_PRIVATE_KEY
# Copy cosign.pub → COSIGN_PUBLIC_KEY
# Remember password → COSIGN_PASSWORD
```

**Example Format**:
```
COSIGN_PRIVATE_KEY:
-----BEGIN ENCRYPTED COSIGN PRIVATE KEY-----
eyJrZGYiOnsibmFtZSI6InNjcnlwdCIsInBhcmFtcyI6eyJOIjozMjc2OCwiciI6
...
-----END ENCRYPTED COSIGN PRIVATE KEY-----

COSIGN_PUBLIC_KEY:
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
-----END PUBLIC KEY-----
```

## 4. Git-Credentials

**Purpose**: Commit Helm changes back to Git

| Variable Name  | Value                              | Secret? |
| -------------- | ---------------------------------- | ------- |
| `GIT_PAT`      | Azure DevOps Personal Access Token | **Yes** |
| `GIT_EMAIL`    | `azure-pipelines@devsecops.local`  | No      |
| `GIT_USERNAME` | `Azure DevOps Pipeline`            | No      |

### Creating PAT (Personal Access Token)

```bash
# Azure DevOps:
# User Settings (top right) → Personal access tokens → New Token

# Settings:
Name: Pipeline GitOps Token
Organization: Your organization
Expiration: 90 days (or as required)

Scopes:
  ✓ Code (Read & Write)  # Required for git push

# Click Create
# Copy the token (shows once!) → GIT_PAT variable
```

## Variable Group Summary

| Group Name      | Variables        | Purpose       |
| --------------- | ---------------- | ------------- |
| AWS-Credentials | 4 variables      | AWS access    |
| Docker-Registry | 3 variables      | ECR URIs      |
| Cosign-Keys     | 3 variables      | Image signing |
| Git-Credentials | 3 variables      | Git push      |
| **Total**       | **13 variables** |               |

## Link to Pipelines

After creating variable groups, link them to pipelines:

### In `azure-pipelines-main.yml`:
```yaml
variables:
  - group: AWS-Credentials
  - group: Docker-Registry
  - group: Cosign-Keys
  - group: Git-Credentials
```

### In `pr-validation.yml`:
```yaml
# PR validation doesn't need credentials
# (no AWS/Git access required)
```

## Security Best Practices

### Azure Key Vault Integration (Recommended)

Instead of storing secrets directly, link to Azure Key Vault:

```bash
# Azure DevOps:
# Library → Variable groups → Link secrets from Azure Key Vault

# Select:
- Azure subscription
- Key Vault name
- Authorize

# Select secrets to sync:
- AWS-SECRET-ACCESS-KEY
- COSIGN-PRIVATE-KEY
- COSIGN-PASSWORD
- GIT-PAT
```

**Benefits**:
- ✅ Centralized secret management
- ✅ Automatic rotation
- ✅ Better access controls
- ✅ Compliance (secrets never in Azure DevOps)

## Verification

Test variables are accessible:

```yaml
# Add test step to pipeline:
- task: Bash@3
  displayName: 'Verify Variables'
  inputs:
    script: |
      echo "AWS_REGION: $(AWS_REGION)"
      echo "ECR_REGISTRY: $(ECR_REGISTRY)"
      echo "GIT_USERNAME: $(GIT_USERNAME)"
      
      # Don't echo secrets!
      if [ -z "$(AWS_SECRET_ACCESS_KEY)" ]; then
        echo "ERROR: AWS_SECRET_ACCESS_KEY not set"
        exit 1
      fi
      
      echo "✓ All variables accessible"
```

## Troubleshooting

### Variable not found
```
Error: $(AWS_ACCESS_KEY_ID) could not be found
```
**Fix**: Ensure variable group is linked in pipeline YAML

### Secret shows as plain text
**Fix**: Check "Keep this value secret" in variable settings

### Git push authentication failed
**Fix**: Verify PAT has "Code (Write)" scope and isn't expired

### Cosign key invalid
**Fix**: Ensure you pasted the ENTIRE key including BEGIN/END lines

## Complete Setup Checklist

- [ ] Created `AWS-Credentials` variable group (4 vars)
- [ ] Created `Docker-Registry` variable group (3 vars)
- [ ] Created `Cosign-Keys` variable group (3 vars)
- [ ] Created `Git-Credentials` variable group (3 vars)
- [ ] Marked sensitive values as secret
- [ ] (Optional) Linked to Azure Key Vault
- [ ] Updated pipeline YAML with variable groups
- [ ] Tested pipeline with verification step
- [ ] Documented PAT expiration date

## Next Steps

After creating all variable groups:

1. Import pipelines to Azure DevOps
2. Run a test build on a feature branch
3. Verify pipeline can access AWS/ECR
4. Verify Cosign signing works
5. Verify GitOps commit succeeds

---

**Note**: Keep PAT tokens secure and rotate regularly!
