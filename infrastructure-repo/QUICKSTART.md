# Quick Start Guide - Azure DevOps Pipelines

## Prerequisites Checklist

- [ ] Azure DevOps project created
- [ ] Repository connected to Azure DevOps
- [ ] AWS account with appropriate permissions
- [ ] Terraform backend resources created (`./scripts/create-backend.sh dev`)

## 5-Minute Setup

### Step 1: Configure Variables (2 minutes)

In Azure DevOps, go to **Pipelines** → **Library** → **+ Variable group**

**Create group: `infrastructure-dev`**
```
AWS_ACCESS_KEY_ID = your-key
AWS_SECRET_ACCESS_KEY = your-secret (🔒 secret)
AWS_REGION = us-east-1
ENVIRONMENT = dev
CLUSTER_NAME = enterprise-devsecops-dev-eks
LB_CONTROLLER_ROLE_ARN = arn:aws:iam::ACCOUNT:role/aws-lb-controller-role
CLUSTER_AUTOSCALER_ROLE_ARN = arn:aws:iam::ACCOUNT:role/cluster-autoscaler-role
```

**Create group: `infrastructure-secrets`**
```
COSIGN_PUBLIC_KEY = $(cat cosign.pub)
```

### Step 2: Create Pipeline (2 minutes)

1. **Pipelines** → **New Pipeline**
2. Select **Azure Repos Git**
3. Select your repository
4. Choose **Existing Azure Pipelines YAML file**
5. Path: `/azure-pipelines-infrastructure.yml`
6. Click **Save**

### Step 3: Run Pipeline (1 minute)

1. Click **Run pipeline**
2. Select `main` branch
3. Click **Run**
4. Wait for validation stage (~5 min)
5. Review Terraform plan artifact
6. **Approve** deployment
7. Monitor progress (~30-40 min total)

## What Gets Deployed

After successful run:
- ✅ EKS Cluster with 2-3 nodes
- ✅ VPC with public  /private subnets
- ✅ IAM roles and policies
- ✅ ECR repositories
- ✅ Argo CD (port-forward to access: `kubectl port-forward svc/argocd-server -n argocd 8080:443`)
- ✅ Kubernetes addons (Metrics Server, AWS LB Controller, Kyverno)
- ✅ Security hardening (Pod Security Standards, Network Policies, Resource Quotas)

## First Deployment Verification

```bash
# Configure kubectl
aws eks update-kubeconfig --name enterprise-devsecops-dev-eks --region us-east-1

# Check cluster
kubectl get nodes

# Check components
kubectl get pods -n argocd
kubectl get pods -n kyverno
kubectl get clusterpolicy

# Get Argo CD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Next Steps

1. Access Argo CD UI (port-forward or create Ingress)
2. Deploy applications via Argo CD
3. Test Kyverno policies
4. Set up monitoring and logging
5. Configure cost alerts

## Troubleshooting

**Pipeline fails at validation?**
→ Check formatting: `terraform fmt -check`

**Terraform init fails?**
→ Create backend: `./scripts/create-backend.sh dev`

**Can't connect to cluster?**
→ Update kubeconfig: `aws eks update-kubeconfig --name <cluster-name>`

For detailed documentation, see [PIPELINE.md](PIPELINE.md)

---

**Estimated Time to First Deployment**: 45 minutes  
**Estimated Cost**: ~$150-200/month for dev environment
