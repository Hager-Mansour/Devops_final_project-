# 📋 Deployment Checklist

Use this checklist to track your progress through the deployment process.

## Phase 1: Azure DevOps Setup ⏱️ 30 min

### Variable Groups
- [ ] Created `AWS-Credentials` variable group
  - [ ] Added `AWS_ACCESS_KEY_ID`
  - [ ] Added `AWS_SECRET_ACCESS_KEY` (marked as secret)
  - [ ] Added `AWS_REGION` = `us-east-1`
  - [ ] Added `AWS_ACCOUNT_ID` = `860973283177`

- [ ] Created `Docker-Registry` variable group
  - [ ] Added `ECR_REGISTRY` = `860973283177.dkr.ecr.us-east-1.amazonaws.com`
  - [ ] Added `FRONTEND_REPO` = `devsecops-dev-frontend`
  - [ ] Added `BACKEND_REPO` = `devsecops-dev-backend`

- [ ] Created `Cosign-Keys` variable group
  - [ ] Copied cosign.key from infrastructure repo
  - [ ] Added `COSIGN_PRIVATE_KEY` (full key, marked as secret)
  - [ ] Added `COSIGN_PUBLIC_KEY` (full public key)
  - [ ] Added `COSIGN_PASSWORD` (marked as secret)

- [ ] Created `Git-Credentials` variable group
  - [ ] Created Azure DevOps PAT with Code (Write) scope
  - [ ] Added `GIT_PAT` (marked as secret)
  - [ ] Added `GIT_EMAIL` = `azure-pipelines@devsecops.local`
  - [ ] Added `GIT_USERNAME` = `Azure DevOps Pipeline`

## Phase 2: Import Pipelines ⏱️ 10 min

- [ ] Created `Application-Repo` in Azure DevOps
- [ ] Pushed code to Application-Repo
  ```bash
  cd /home/karim/Final-Project/project/
  git remote add origin <your-azure-devops-url>
  git push -u origin main
  ```
- [ ] Imported PR validation pipeline (`.azure-pipelines/pr-validation.yml`)
- [ ] Imported main release pipeline (`.azure-pipelines/azure-pipelines-main.yml`)
- [ ] Verified variable groups are linked in pipeline YAML

## Phase 3: ArgoCD Configuration ⏱️ 5 min

- [ ] Updated `argocd-application.yaml` with correct repo URL
- [ ] Committed and pushed the change
- [ ] Applied ArgoCD Application to cluster:
  ```bash
  kubectl apply -f argocd-application.yaml -n argocd
  ```
- [ ] Verified application created:
  ```bash
  kubectl get application -n argocd microservices-app
  ```
  Expected: Shows `OutOfSync` (normal before first build)

## Phase 4: First Deployment ⏱️ 30 min

### Prepare Application Code
- [ ] Created `frontend/Dockerfile`
- [ ] Created `backend/Dockerfile`
- [ ] Committed Dockerfiles to Git
- [ ] Pushed to main branch

### Run Pipeline
- [ ] Triggered main release pipeline in Azure DevOps
- [ ] Stage 1: Prerequisites ✅
- [ ] Stage 2: Build ✅
- [ ] Stage 3: Security Scanning ✅
- [ ] Stage 4: Push to ECR ✅
- [ ] Stage 5: Sign Images ✅
- [ ] Stage 6: Generate SBOM ✅
- [ ] Stage 7: Update Helm Values ✅
- [ ] Stage 8: Summary ✅

### Verify ArgoCD Sync
- [ ] ArgoCD detected Helm values change
- [ ] ArgoCD status: `Synced`
- [ ] ArgoCD health: `Healthy`

### Verify Pods
- [ ] Frontend pod 1 running
- [ ] Frontend pod 2 running
- [ ] Backend pod 1 running
- [ ] Backend pod 2 running
- [ ] PostgreSQL pod (StatefulSet) running

Commands to check:
```bash
kubectl get pods -n dev
kubectl get pvc -n dev  # Check PostgreSQL storage
kubectl get svc -n dev   # Check services
```

## Phase 5: Test & Verify ⏱️ 15 min

### Database
- [ ] Connected to PostgreSQL pod successfully
  ```bash
  kubectl exec -it microservices-app-postgres-0 -n dev -- psql -U postgres -d microservices_db
  ```
- [ ] Database persistent (PVC bound)
- [ ] Backend logs show successful DB connection

### Application Access
- [ ] Frontend accessible via port-forward
  ```bash
  kubectl port-forward svc/microservices-app-frontend -n dev 8080:80
  # Open http://localhost:8080
  ```
- [ ] Backend accessible via port-forward
  ```bash
  kubectl port-forward svc/microservices-app-backend -n dev 8081:5000
  # curl http://localhost:8081/health
  ```

### Security
- [ ] Checked Kyverno policy reports (no violations)
  ```bash
  kubectl get policyreport -A
  ```
- [ ] Image signatures verified (no unsigned image alerts)
- [ ] SBOM artifacts published in Azure DevOps

### Monitoring
- [ ] Logs visible in CloudWatch
- [ ] Pod metrics visible in CloudWatch Container Insights
- [ ] No CrashLoopBackOff pods

## Phase 6: GitOps Test ⏱️ 10 min

- [ ] Made a code change (any file)
- [ ] Committed and pushed to main
- [ ] Pipeline automatically triggered
- [ ] Pipeline completed successfully
- [ ] Helm values.yaml updated with new image tag
- [ ] ArgoCD detected change within 3 minutes
- [ ] ArgoCD synced new deployment
- [ ] Pods rolled out with new images
- [ ] Zero downtime during update

## 🎯 Final Success Criteria

Mark these when everything is working:

- [ ] ✅ All 13 variables in 4 variable groups configured
- [ ] ✅ Both pipelines visible in Azure DevOps
- [ ] ✅ First deployment completed end-to-end
- [ ] ✅ 5 pods running (2 frontend, 2 backend, 1 postgres)
- [ ] ✅ PostgreSQL data persists across pod restarts
- [ ] ✅ Can access frontend and backend
- [ ] ✅ ArgoCD UI shows application as Healthy
- [ ] ✅ Kyverno verified all image signatures
- [ ] ✅ CloudWatch logs receiving data
- [ ] ✅ GitOps cycle working (code push → auto-deploy)
- [ ] ✅ SBOMs generated and published

## 🚨 If Stuck

| Problem                 | Quick Fix                                             |
| ----------------------- | ----------------------------------------------------- |
| Pipeline fails on Trivy | Update vulnerable dependencies                        |
| Cosign signing fails    | Check COSIGN_PRIVATE_KEY includes BEGIN/END lines     |
| ArgoCD won't sync       | Run `argocd app sync microservices-app --force`       |
| Pods Pending            | Check `kubectl describe pod <name> -n dev` for events |
| Image pull error        | Verify ECR login in pipeline succeeded                |
| Kyverno blocks pods     | Verify image was signed in pipeline                   |
| Database not persistent | Check PVC exists: `kubectl get pvc -n dev`            |
| Can't access pods       | Firewall/network policies - use port-forward          |

## 📞 Where to Get Help

1. **Check logs first**:
   ```bash
   # ArgoCD logs
   kubectl logs -n argocd deployment/argocd-repo-server
   
   # Application logs
   kubectl logs -n dev <pod-name>
   
   # Pipeline logs
   # Azure DevOps → Pipeline run → View logs
   ```

2. **Check documentation**:
   - [GETTING_STARTED.md](GETTING_STARTED.md) - Detailed steps
   - [docs/GITOPS.md](docs/GITOPS.md) - ArgoCD troubleshooting
   - [docs/SECURITY.md](docs/SECURITY.md) - Security issues
   - [VARIABLE_GROUPS_SETUP.md](VARIABLE_GROUPS_SETUP.md) - Variable setup

3. **Verify state**:
   ```bash
   # Check everything in one command
   kubectl get all,pvc,policyreport -n dev
   kubectl get application -n argocd
   argocd app get microservices-app
   ```

## 📊 Progress Tracker

Track your overall progress:

```
Phase 1: Azure DevOps Setup         [ ] Not Started  [ ] In Progress  [ ] Complete
Phase 2: Import Pipelines           [ ] Not Started  [ ] In Progress  [ ] Complete
Phase 3: ArgoCD Configuration       [ ] Not Started  [ ] In Progress  [ ] Complete
Phase 4: First Deployment           [ ] Not Started  [ ] In Progress  [ ] Complete
Phase 5: Test & Verify              [ ] Not Started  [ ] In Progress  [ ] Complete
Phase 6: GitOps Test                [ ] Not Started  [ ] In Progress  [ ] Complete
```

---

**Current Status**: Ready to begin Phase 1! Start with [GETTING_STARTED.md](GETTING_STARTED.md) 🚀
