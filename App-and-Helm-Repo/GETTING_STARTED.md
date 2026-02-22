# 🚀 Getting Started - Step-by-Step Guide

## Your Current Situation

✅ **Infrastructure Repo** - EKS cluster with ArgoCD installed
✅ **Application Repo** - Complete Helm chart and pipelines created
❓ **Next Steps** - How to deploy everything

## Prerequisites Checklist

Before starting, verify you have:

- [ ] EKS cluster running (from infrastructure repo)
- [ ] ArgoCD installed on EKS cluster
- [ ] AWS ECR repositories created (`devsecops-dev-frontend`, `devsecops-dev-backend`)
- [ ] Cosign keys generated (from infrastructure repo)
- [ ] Azure DevOps project created
- [ ] Git repository for application code

## Step-by-Step Deployment

### **PHASE 1: Setup Azure DevOps** (30 minutes)

#### Step 1.1: Create Variable Groups

Go to Azure DevOps → Your Project → Pipelines → Library → + Variable group

**Create 4 variable groups** (see [VARIABLE_GROUPS_SETUP.md](VARIABLE_GROUPS_SETUP.md) for details):

```
1. AWS-Credentials (4 variables)
   - AWS_ACCESS_KEY_ID
   - AWS_SECRET_ACCESS_KEY (secret)
   - AWS_REGION
   - AWS_ACCOUNT_ID

2. Docker-Registry (3 variables)
   - ECR_REGISTRY
   - FRONTEND_REPO
   - BACKEND_REPO

3. Cosign-Keys (3 variables)
   - COSIGN_PRIVATE_KEY (secret)
   - COSIGN_PUBLIC_KEY
   - COSIGN_PASSWORD (secret)

4. Git-Credentials (3 variables)
   - GIT_PAT (secret)
   - GIT_EMAIL
   - GIT_USERNAME
```

**Don't skip this!** Pipelines won't work without these.

#### Step 1.2: Get Cosign Keys from Infrastructure Repo

```bash
# Navigate to infrastructure repo
cd /home/karim/Final-Project/enterprise-devsecops-project/infrastructure-repo

# Display the keys
cat cosign.key
cat cosign.pub

# Copy the ENTIRE content (including BEGIN/END lines)
# Paste into Azure DevOps variable groups
```

#### Step 1.3: Create Azure DevOps PAT

```
Azure DevOps → User Settings (top right) → Personal access tokens → New Token

Name: Pipeline GitOps Token
Scope: Code (Read & Write)
Expiration: 90 days

Copy the token → Paste into Git-Credentials variable group
```

### **PHASE 2: Import Pipelines** (10 minutes)

#### Step 2.1: Create Git Repository in Azure DevOps

```
Azure DevOps → Repos → Create new repository
Name: Application-Repo
Initialize with README: No
```

#### Step 2.2: Push Application Code

```bash
# Navigate to project directory
cd /home/karim/Final-Project/project/

# Initialize git (if not already)
git init
git remote add origin https://dev.azure.com/<org>/<project>/_git/Application-Repo

# Add all files
git add .
git commit -m "feat: Initial DevSecOps setup with Helm and pipelines"

# Push to Azure DevOps
git push -u origin main
```

#### Step 2.3: Import PR Validation Pipeline

```
Azure DevOps → Pipelines → New pipeline

1. Where is your code? → Azure Repos Git
2. Select repository → Application-Repo
3. Configure → Existing Azure Pipelines YAML file
4. Path: /.azure-pipelines/pr-validation.yml
5. Save (don't run yet)

Name the pipeline: "PR Validation"
```

#### Step 2.4: Import Main Release Pipeline

```
Azure DevOps → Pipelines → New pipeline

1. Where is your code? → Azure Repos Git
2. Select repository → Application-Repo
3. Configure → Existing Azure Pipelines YAML file
4. Path: /.azure-pipelines/azure-pipelines-main.yml
5. Save (don't run yet)

Name the pipeline: "Main Release - DevSecOps"
```

#### Step 2.5: Link Variable Groups to Pipeline

```yaml
# Edit azure-pipelines-main.yml (already has this at top):
variables:
  - group: AWS-Credentials
  - group: Docker-Registry
  - group: Cosign-Keys
  - group: Git-Credentials

# Verify these group names match what you created in Step 1.1
```

### **PHASE 3: Update ArgoCD Configuration** (5 minutes)

#### Step 3.1: Fix ArgoCD Application Manifest

Edit `argocd-application.yaml` with your actual Git URL:

```bash
# Open the file
nano /home/karim/Final-Project/project/argocd-application.yaml

# Update line 13:
repoURL: https://dev.azure.com/<your-org>/<your-project>/_git/Application-Repo

# Save and commit
git add argocd-application.yaml
git commit -m "fix: Update ArgoCD repo URL"
git push
```

#### Step 3.2: Deploy ArgoCD Application

```bash
# Make sure kubectl is pointing to your EKS cluster
kubectl config current-context

# Apply the ArgoCD application
kubectl apply -f argocd-application.yaml -n argocd

# Verify it was created
kubectl get application -n argocd microservices-app

# Expected output:
# NAME                SYNC STATUS   HEALTH STATUS
# microservices-app   OutOfSync     Missing
```

**Why OutOfSync?** ArgoCD is waiting for you to build images first!

### **PHASE 4: First Deployment** (30 minutes)

#### Step 4.1: Create Frontend and Backend Dockerfiles

You need to create actual Dockerfiles for your apps:

**Frontend Dockerfile** (`frontend/Dockerfile`):
```dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**Backend Dockerfile** (`backend/Dockerfile`):
```dockerfile
FROM python:3.11-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY . .
EXPOSE 5000
USER 1000
CMD ["python", "app.py"]
```

Commit these:
```bash
git add frontend/Dockerfile backend/Dockerfile
git commit -m "feat: Add production Dockerfiles"
git push
```

#### Step 4.2: Trigger First Pipeline Run

```
Azure DevOps → Pipelines → Main Release - DevSecOps → Run pipeline

Branch: main
Click "Run"
```

**Watch the pipeline execute** (15-20 minutes):
1. ✅ Prerequisites check
2. ✅ Build images
3. ⚠️ Security scan (may fail if vulnerabilities found - fix them!)
4. ✅ Push to ECR
5. ✅ Sign with Cosign
6. ✅ Generate SBOM
7. ✅ Update Helm values
8. ✅ Git commit

#### Step 4.3: Wait for ArgoCD Sync

```bash
# Watch ArgoCD detect the change
watch -n 5 "kubectl get application -n argocd microservices-app"

# After 3 minutes (ArgoCD poll interval):
# SYNC STATUS changes: OutOfSync → Syncing → Synced
# HEALTH STATUS: Missing → Progressing → Healthy
```

#### Step 4.4: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n dev

# Expected output:
# NAME                                READY   STATUS    RESTARTS   AGE
# microservices-app-frontend-xxx      1/1     Running   0          2m
# microservices-app-frontend-xxx      1/1     Running   0          2m
# microservices-app-backend-xxx       1/1     Running   0          2m
# microservices-app-backend-xxx       1/1     Running   0          2m
# microservices-app-postgres-0        1/1     Running   0          2m

# Check services
kubectl get svc -n dev

# Check ArgoCD UI
# Get ArgoCD password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# Port forward to ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open in browser: https://localhost:8080
# Login: admin / <password from above>
```

### **PHASE 5: Test & Verify** (15 minutes)

#### Step 5.1: Test Database Connection

```bash
# Connect to PostgreSQL pod
kubectl exec -it microservices-app-postgres-0 -n dev -- psql -U postgres -d microservices_db

# Inside psql:
\l                    # List databases
\dt                   # List tables (if any)
\q                    # Quit

# Test backend can connect
kubectl logs -n dev <backend-pod-name> | grep -i database
```

#### Step 5.2: Test Service Communication

```bash
# Port forward to frontend
kubectl port-forward svc/microservices-app-frontend -n dev 8081:80

# Open browser: http://localhost:8081
# Should see your frontend (might show errors if no API yet)

# Port forward to backend
kubectl port-forward svc/microservices-app-backend -n dev 8082:5000

# Test backend health endpoint
curl http://localhost:8082/health
```

#### Step 5.3: Verify Image Signatures

```bash
# Check Kyverno policy reports
kubectl get policyreport -A

# Should show image signature verifications passed
# If you see failures, images weren't signed correctly
```

#### Step 5.4: Check Monitoring

```bash
# View application logs
kubectl logs -n dev -l app.kubernetes.io/component=backend --tail=50

# Check CloudWatch Logs (AWS Console)
# Navigate to: CloudWatch → Log groups
# Find: /aws/containerinsights/devsecops-dev-eks/application
```

### **PHASE 6: Make a Change (GitOps Test)** (10 minutes)

#### Step 6.1: Update Application Code

```bash
# Make a small change to backend
echo "# Updated on $(date)" >> backend/README.md

git add backend/README.md
git commit -m "test: Trigger pipeline for GitOps demo"
git push
```

#### Step 6.2: Watch the Full GitOps Cycle

```bash
# Watch pipeline run
# Azure DevOps → Pipelines → Main Release - DevSecOps

# After pipeline completes, watch ArgoCD
watch -n 5 "kubectl get application -n argocd microservices-app -o jsonpath='{.status.sync.status}'"

# Watch pods rolling update
kubectl get pods -n dev -w
```

**Success!** You've completed a full GitOps cycle:
```
Code change → Pipeline → Build → Scan → Sign → SBOM → Git commit → ArgoCD sync → Deploy
```

## 📊 Success Criteria

Your deployment is successful when:

- [ ] All 4 Azure DevOps variable groups created
- [ ] Both pipelines imported and visible
- [ ] First pipeline run completed successfully
- [ ] ArgoCD Application shows "Synced" and "Healthy"
- [ ] All 5 pods running in `dev` namespace
  - 2 frontend pods
  - 2 backend pods
  - 1 postgres pod
- [ ] Image signatures verified by Kyverno
- [ ] Can access frontend via port-forward
- [ ] Can access backend via port-forward
- [ ] Database is persistent (survives pod restart)
- [ ] GitOps cycle works (code push → auto-deploy)

## 🚨 Troubleshooting Common Issues

### Issue 1: Pipeline Fails on Trivy Scan
```
Error: Trivy found HIGH/CRITICAL vulnerabilities
```
**Fix**: Update base images or vulnerable dependencies in requirements.txt/package.json

### Issue 2: Cosign Signing Fails
```
Error: Failed to sign image
```
**Fix**: 
- Verify COSIGN_PRIVATE_KEY has full content (including BEGIN/END)
- Check COSIGN_PASSWORD is correct
- Ensure ECR login succeeded

### Issue 3: ArgoCD Stuck OutOfSync
```
ArgoCD shows OutOfSync for 10+ minutes
```
**Fix**:
```bash
# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-repo-server

# Manual sync
argocd app sync microservices-app --force

# Check repo URL is correct
kubectl get application microservices-app -n argocd -o yaml | grep repoURL
```

### Issue 4: Pods Pending
```
Pods stuck in Pending state
```
**Fix**:
```bash
# Check events
kubectl describe pod <pod-name> -n dev

# Common causes:
# - Insufficient resources (need more nodes)
# - Image pull error (ECR auth failed)
# - PVC not bound (storage class issue)

# Check PVC
kubectl get pvc -n dev
```

### Issue 5: Kyverno Blocks Deployment
```
Error: Image signature verification failed
```
**Fix**:
```bash
# Check if image was actually signed
cosign verify --key cosign.pub \
  860973283177.dkr.ecr.us-east-1.amazonaws.com/devsecops-dev-backend:<tag>

# If not signed, re-run pipeline
# If signed but Kyverno blocks, check public key matches
```

## 📚 Next Steps After Successful Deployment

1. **Enable Ingress** - Expose frontend publicly
   ```yaml
   # In values.yaml
   ingress:
     enabled: true
   ```

2. **Setup Monitoring Alerts** - CloudWatch alarms
3. **Add More Environments** - Staging, Production
4. **Implement Backup** - PostgreSQL backup CronJob
5. **Setup Secrets Rotation** - External Secrets Operator
6. **Add HPA** - Horizontal Pod Autoscaler
7. **Network Policies** - Restrict pod-to-pod traffic

## 🎯 Where You Are Now

```
✅ Infrastructure Repo (EKS + ArgoCD)
✅ Application Repo (Helm + Pipelines)
❌ Not deployed yet

After following this guide:
✅✅ Fully deployed and working!
```

## Quick Reference Commands

```bash
# Watch ArgoCD sync
kubectl get app -n argocd microservices-app -w

# Watch pods deploy
kubectl get pods -n dev -w

# Check logs
kubectl logs -n dev -l app.kubernetes.io/component=backend -f

# Port forward frontend
kubectl port-forward svc/microservices-app-frontend -n dev 8080:80

# Trigger manual sync
argocd app sync microservices-app

# Check image in ECR
aws ecr describe-images \
  --repository-name devsecops-dev-backend \
  --region us-east-1

# Verify signature
cosign verify --key cosign.pub <image-uri>
```

---

**Start with PHASE 1 and work through sequentially. Good luck! 🚀**
