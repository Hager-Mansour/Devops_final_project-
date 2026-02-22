# Azure DevOps Pipeline Documentation

## Overview

This directory contains Azure DevOps pipelines for deploying and managing EKS infrastructure using Terraform and Ansible.

## 📋 Pipelines

### 1. Infrastructure Deployment (`azure-pipelines-infrastructure.yml`)

**Purpose**: Deploy EKS cluster and configure it with Kubernetes resources.

**Triggered By**:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Changes to `terraform/`, `ansible/`, or `scripts/` directories

**Stages**:

1. **Validation & Security Scanning**
   - Pre-flight checks
   - Terraform formatting validation
   - Ansible syntax validation
   - Security scanning (tfsec, Checkov)

2. **Terraform Plan**
   - Initialize Terraform backend
   - Generate execution plan
   - Publish plan as artifact for review

3. **Manual Approval** (Optional)
   - Review Terraform plan
   - Approve or reject deployment
   - Skipped if `AUTO_APPROVE=true`

4. **Terraform Apply**
   - Apply infrastructure changes
   - Create EKS cluster, VPC, IAM, ECR
   - Export outputs for Ansible

5. **Ansible Configuration**
   - Configure kubectl access
   - Set up namespaces and security
   - Install Argo CD
   - Install Kubernetes addons (Metrics Server, AWS LB Controller, Kyverno)
   - Apply security hardening

6. **Verification**
   - Check cluster health
   - Verify all components
   - Test Kyverno policies
   - Generate deployment report

**Duration**: ~30-45 minutes

---

### 2. Infrastructure Destroy (`azure-pipelines-destroy.yml`)

**Purpose**: Safely destroy all infrastructure resources.

> [!CAUTION]
> This is a DESTRUCTIVE operation. Use with extreme caution!

**Triggered By**: Manual trigger only

**Safety Features**:
- Requires typing "DESTROY" to confirm
- Two manual approval gates
- State backup verification
- Manual environment selection

**Stages**:
1. Validate destroy request
2. First approval gate
3. Backup verification
4. Second approval gate
5. Terraform destroy

**Duration**: ~15-20 minutes (plus approval time)

---

## 🔧 Setup Instructions

### 1. Create Variable Groups in Azure DevOps

Navigate to **Pipelines** → **Library** → **Variable groups**

#### Group: `infrastructure-dev`
```yaml
AWS_ACCESS_KEY_ID: "your-access-key"  # Or use service connection
AWS_SECRET_ACCESS_KEY: "***"  # Mark as secret
AWS_REGION: "us-east-1"
ENVIRONMENT: "dev"
CLUSTER_NAME: "enterprise-devsecops-dev-eks"
LB_CONTROLLER_ROLE_ARN: "arn:aws:iam::ACCOUNT:role/aws-lb-controller-role"
CLUSTER_AUTOSCALER_ROLE_ARN: "arn:aws:iam::ACCOUNT:role/cluster-autoscaler-role"
```

#### Group: `infrastructure-staging`
Same as above, but with `staging` values.

#### Group: `infrastructure-prod`
Same as above, but with `prod` values and stricter configurations.

#### Group: `infrastructure-secrets`
```yaml
COSIGN_PRIVATE_KEY: "***"  # Mark as secret
COSIGN_PUBLIC_KEY: "ssh-rsa AAAA..."
```

### 2. Create Pipelines in Azure DevOps

1. Go to **Pipelines** → **New Pipeline**
2. Select **Azure Repos Git** (or your source)
3. Select your repository
4. Choose **Existing Azure Pipelines YAML file**
5. Select `/azure-pipelines-infrastructure.yml`
6. Save (don't run yet)

Repeat for `/azure-pipelines-destroy.yml`.

### 3. Configure Pipeline Permissions

1. Go to **Project Settings** → **Service connections**
2. Create AWS service connection (optional, alternative to access keys)
3. Grant pipeline access to service connection

### 4. Set Up Approval Gates

1. Go to **Pipelines** → Select pipeline → **Edit**
2. Click on **Triggers** tab
3. Under **Approvals**, add required approvers for production

---

## 🔐 Required Variables

### AWS Credentials

**Option 1: Service Connection** (Recommended)
- Create AWS service connection in Azure DevOps
- Reference in pipeline with `awsCredentials` parameter

**Option 2: Pipeline Variables**
- `AWS_ACCESS_KEY_ID`: AWS access key
- `AWS_SECRET_ACCESS_KEY`: AWS secret key (secret)
- `AWS_REGION`: AWS region (e.g., `us-east-1`)

### Environment Configuration

- `ENVIRONMENT`: Environment name (`dev`, `staging`, `prod`)
- `CLUSTER_NAME`: EKS cluster name
- `LB_CONTROLLER_ROLE_ARN`: IAM role ARN for AWS Load Balancer Controller
- `CLUSTER_AUTOSCALER_ROLE_ARN`: IAM role ARN for Cluster Autoscaler (optional)

### Security

- `COSIGN_PUBLIC_KEY`: Cosign public key for image verification
- `COSIGN_PRIVATE_KEY`: Cosign private key for image signing (secret)

### Optional

- `AUTO_APPROVE`: Set to `true` to skip approval gates (not recommended for prod)
- `terraformVersion`: Terraform version (default: `1.6.0`)
- `ansibleVersion`: Ansible version (default: `2.14`)

---

## 🚀 Running the Pipeline

### First Time Deployment

1. **Create Backend Resources**:
   ```bash
   ./scripts/create-backend.sh dev
   ```

2. **Set Variables in Azure DevOps**:
   - Configure all required variable groups

3. **Run Pipeline**:
   - Go to **Pipelines** → Select **infrastructure-deployment**
   - Click **Run pipeline**
   - Select branch and environment
   - Click **Run**

4. **Review Plan**:
   - Wait for plan stage to complete
   - Download and review Terraform plan artifact
   - Approve deployment

5. **Monitor Deployment**:
   - Watch logs for each stage
   - Verify successful completion

### Subsequent Deployments

1. Make changes to Terraform or Ansible code
2. Commit and push to `develop` or `main`
3. Pipeline auto-triggers
4. Review and approve plan
5. Monitor deployment

---

## 📊 Pipeline Templates

Reusable templates in `pipelines/templates/`:

### `terraform-install.yml`
- Installs Terraform with version pinning
- Caches binary for faster runs
- **Parameters**: `terraformVersion`

### `aws-credentials.yml`
- Configures AWS CLI credentials
- Sets up environment variables
- **Parameters**: `awsAccessKeyId`, `awsSecretAccessKey`, `awsRegion`

### `ansible-install.yml`
- Installs Ansible and collections
- Caches Python packages
- **Parameters**: `ansibleVersion`

**Usage Example**:
```yaml
- template: pipelines/templates/terraform-install.yml
  parameters:
    terraformVersion: '1.6.0'
```

---

## 🔍 Monitoring & Logs

### View Pipeline Logs

1. Go to **Pipelines** → Select run
2. Click on each stage to view logs
3. Download logs for debugging

### Artifacts

Published artifacts after each run:
- `terraform-plan`: Terraform execution plan
- `terraform-plan-output`: Human-readable plan
- `terraform-outputs`: Terraform output values (JSON)

### Terraform State

- Stored in S3: `s3://devsecops-terraform-state-{environment}/eks-infrastructure/terraform.tfstate`
- Encrypted at rest (AES256)
- Versioned for recovery
- Locked via DynamoDB

---

## 🐛 Troubleshooting

### Pipeline Fails at Validation Stage

**Issue**: Pre-flight checks fail

**Solutions**:
- Review validation errors in logs
- Run `./scripts/preflight-check.sh` locally
- Check Terraform formatting: `terraform fmt -check`
- Verify Ansible syntax: `ansible-playbook playbooks/*.yml --syntax-check`

### Terraform Init Fails

**Issue**: Backend initialization error

**Cause**: S3 bucket or DynamoDB table doesn't exist

**Solution**:
```bash
./scripts/create-backend.sh dev
```

### Terraform Apply Fails

**Issue**: Resource creation error

**Solutions**:
- Check AWS credentials and permissions
- Verify IAM policies allow required actions
- Review Terraform logs for specific error
- Check AWS service quotas

### Ansible Fails to Connect

**Issue**: kubectl cannot connect to cluster

**Solutions**:
- Verify EKS cluster exists: `aws eks list-clusters`
- Check IAM permissions for EKS access
- Verify cluster endpoint is accessible
- Review security group rules

### Kyverno Policy Test Fails

**Issue**: Policy enforcement not working

**Solutions**:
- Check Kyverno pods: `kubectl get pods -n kyverno`
- Verify policies applied: `kubectl get clusterpolicy`
- Review Kyverno logs
- Ensure COSIGN_PUBLIC_KEY is set correctly

---

## 🔒 Security Best Practices

### Secrets Management

- ✅ Never commit secrets to Git
- ✅ Use Azure DevOps secret variables
- ✅ Rotate AWS credentials regularly
- ✅ Use IAM roles where possible
- ✅ Enable MFA for pipeline approvals

### Access Control

- ✅ Require approval for production deployments
- ✅ Limit pipeline edit permissions
- ✅ Use separate variable groups per environment
- ✅ Audit pipeline runs regularly

### State Management

- ✅ S3 bucket encryption enabled
- ✅ Versioning enabled for rollback
- ✅ State locking with DynamoDB
- ✅ Public access blocked
- ✅ Bucket logging enabled

---

## 📈 Multi-Environment Strategy

### Environment Separation

Each environment (`dev`, `staging`, `prod`) has:
- Separate variable group
- Separate S3 backend bucket
- Separate cluster name
- Environment-specific configurations

### Promotion Workflow

1. **Dev**: Automatic deployment on push to `develop`
2. **Staging**: Manual trigger or automatic on merge to `main`
3. **Prod**: Manual trigger with strict approvals

### Variable Differences

**Dev**:
- Smaller instance types
- Single AZ deployment
- Minimal redundancy

**Staging**:
- Production-like configuration
- Multi-AZ deployment
- Testing environment

**Prod**:
- High availability
- Multi-AZ deployment
- Enhanced monitoring
- Strict approval gates

---

## 🔄 Rollback Procedures

### Automatic Rollback

Terraform changes are atomic:
- If apply fails, no resources are modified
- Previous state is preserved

### Manual Rollback

**Method 1: Revert Git Commit**
```bash
git revert <commit-hash>
git push
# Pipeline auto-triggers with previous config
```

**Method 2: Redeploy Previous Version**
1. Check out previous commit
2. Run pipeline manually
3. Review and apply

**Method 3: Destroy and Recreate**
1. Run destroy pipeline
2. Fix issues in code
3. Run infrastructure pipeline

---

## 📝 Pipeline Customization

### Adding New Stages

Edit `azure-pipelines-infrastructure.yml`:

```yaml
- stage: CustomStage
  displayName: 'My Custom Stage'
  dependsOn: PreviousStage
  jobs:
    - job: CustomJob
      steps:
        - script: echo "Custom logic"
```

### Adding Security Scans

Add to validation stage:

```yaml
- script: |
    # Example: Add Trivy scan
    trivy filesystem --exit-code 1 .
  displayName: 'Trivy Filesystem Scan'
```

### Notifications

Add to end of pipeline:

```yaml
- task: SendEmail@1
  inputs:
    to: 'team@example.com'
    subject: 'Deployment $(Build.BuildNumber) - $(Environment)'
    body: 'Deployment completed successfully!'
```

---

## 📚 Additional Resources

- [Terraform Backend Configuration](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [Azure DevOps YAML Schema](https://learn.microsoft.com/en-us/azure/devops/pipelines/yaml-schema/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Kyverno Policies](https://kyverno.io/policies/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

---

## 🆘 Support

For issues or questions:
1. Review this documentation
2. Check pipeline logs
3. Review validation report: `validation_report.md`
4. Run pre-flight check: `./scripts/preflight-check.sh`
5. Check Terraform/Ansible documentation

---

**Pipeline Version**: 1.0.0  
**Last Updated**: 2026-02-04
