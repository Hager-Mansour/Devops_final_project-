# GitOps Deployment with ArgoCD

## Overview

This document explains how ArgoCD implements GitOps for continuous deployment of the microservices application.

## Why GitOps?

### Benefits
1. **Declarative Infrastructure**: Entire application state defined in Git
2. **Version Control**: Complete audit trail of all changes
3. **Rollback Capability**: Git revert = instant rollback
4. **Security**: No direct kubectl access needed
5. **Consistency**: Same deployment process across all environments
6. **Compliance**: Auditable deployment history

### GitOps Principles
- Git is the single source of truth
- Pull-based deployment (ArgoCD pulls from Git)
- Automatic synchronization
- Continuous reconciliation

## ArgoCD Architecture

```
┌─────────────────┐
│  Developer      │
│  Pushes Code    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Azure Pipeline │
│  - Build Images │         ┌──────────────┐
│  - Scan/Sign    │────────▶│  ECR Registry│
│  - Update Helm  │         └──────────────┘
└────────┬────────┘
         │
         │ Git Commit
         ▼
┌─────────────────┐
│  Git Repository │◀────┐
│  (Helm Charts)  │     │
└────────┬────────┘     │
         │              │ Polls every 3min
         │              │
         ▼              │
   ┌─────────────────┐  │
   │  ArgoCD Server  │──┘
   │  - Detects Δ    │
   │  - Syncs State  │
   └────────┬────────┘
            │
            │ kubectl apply
            ▼
   ┌─────────────────┐
   │  EKS Cluster    │
   │  - Pods Update  │
   │  - Health Check │
   └─────────────────┘
```

## How ArgoCD Detects Changes

### Polling Mechanism
- **Default**: ArgoCD polls Git repo every **3 minutes**
- **Webhook**: Optional webhook for instant detection
- **Manual Sync**: Can trigger sync via UI/CLI

### Change Detection
ArgoCD compares:
1. **Desired State**: Current state in Git repository
2. **Live State**: Actual resources in Kubernetes cluster
3. **Diff Calculation**: Identifies resources that need update

### What Triggers Deployment
```yaml
# When this changes in values.yaml:
frontend:
  image:
    tag: abc123  # ← Change detected here

# ArgoCD automatically:
# 1. Pulls new Helm chart
# 2. Renders templates with new tag
# 3. Applies to Kubernetes
# 4. Waits for pods to be Ready
```

## Deployment Workflow

### 1. Developer Pushes Code
```bash
git add .
git commit -m "feat: Add new feature"
git push origin main
```

### 2. Azure Pipeline Executes
```
Build → Scan → Push → Sign → SBOM → Update Helm → Commit
```

### 3. Helm Values Updated
```yaml
# pipeline commits:
backend:
  image:
    tag: abc123def456  # Git SHA
```

### 4. ArgoCD Detects Change
```
ArgoCD polls → Sees new commit → Calculates diff → Begins sync
```

### 5. Kubernetes Resources Updated
```
ArgoCD executes:
kubectl apply -f deployment.yaml (with new image tag)
kubectl rollout status deployment/backend
```

### 6. Health Checks
```
ArgoCD monitors:
- Deployment progressing
- Pods becoming Ready
- Service endpoints available
```

## Sync Behavior

### Automatic Sync
Configured in Application manifest:
```yaml
syncPolicy:
  automated:
    prune: true        # Delete removed resources
    selfHeal: true     # Revert manual changes
```

**prune**: If you delete a deployment from Git, ArgoCD deletes it from cluster.
**selfHeal**: If someone runs `kubectl edit`, ArgoCD reverts it.

### Manual Sync
Option to disable automated sync for production:
```yaml
syncPolicy: {}  # No automated sync
```
Then manually sync via:
```bash
argocd app sync microservices-app
```

## Rollback Strategy

### Method 1: Git Revert (Recommended)
```bash
# Find previous commit
git log --oneline helm/app/values.yaml

# Revert to previous version
git revert <commit-hash>
git push

# ArgoCD automatically deploys old version
```

### Method 2: ArgoCD History
```bash
# View deployment history
argocd app history microservices-app

# Rollback to specific revision
argocd app rollback microservices-app 10
```

### Method 3: Update values.yaml
```bash
# Edit values.yaml with old image tag
sed -i 's/tag: new-tag/tag: old-tag/' helm/app/values.yaml
git add helm/app/values.yaml
git commit -m "rollback: Revert to previous version"
git push
```

## Promotion Flow Across Environments

### Environment Strategy
```
┌─────────────────────────────────────────────────┐
│  Git Repository (Single Repo, Multiple Dirs)   │
├─────────────────────────────────────────────────┤
│  helm/app/values-dev.yaml                       │
│  helm/app/values-staging.yaml                   │
│  helm/app/values-prod.yaml                      │
└─────────────────────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
   ┌─────────┐  ┌─────────┐  ┌─────────┐
   │   Dev   │  │ Staging │  │  Prod   │
   │ Cluster │  │ Cluster │  │ Cluster │
   └─────────┘  └─────────┘  └─────────┘
```

### Promotion Process
```bash
# 1. Deploy to Dev (automatic)
Azure Pipeline → Updates values-dev.yaml → ArgoCD syncs to Dev

# 2. Promote to Staging (manual approval)
git cherry-pick <dev-commit>
# Update values-staging.yaml with same image tag
git push
# ArgoCD syncs to Staging

# 3. Promote to Prod (manual approval + review)
git cherry-pick <staging-commit>
# Update values-prod.yaml with same image tag
git push
# ArgoCD syncs to Prod
```

### Alternative: Branch-Based
```
main branch          → Prod
staging branch       → Staging  
develop branch       → Dev
```

## Health Assessment

ArgoCD monitors application health:

### Healthy Criteria
```yaml
✓ All pods Running
✓ Readiness probes passing
✓ Service endpoints available
✓ No CrashLoopBackOff
```

### Degraded State
```yaml
⚠ Some pods not Ready
⚠ Readiness probe failing
⚠ Recent restarts
```

### Failed State
```yaml
✗ Pods in Error/CrashLoop
✗ Deployment stuck progressing
✗ Image pull failures
```

## Monitoring ArgoCD

### Web UI
```
https://<argocd-server>/applications/microservices-app
```

Shows:
- Current sync status
- Last sync time
- Resource tree
- Event history
- Diff view

### CLI
```bash
# Application status
argocd app get microservices-app

# Live logs
argocd app logs microservices-app

# Sync history
argocd app history microservices-app
```

### Metrics
ArgoCD exposes Prometheus metrics:
```
argocd_app_sync_total
argocd_app_sync_status
argocd_app_health_status
```

## Best Practices

### 1. Small, Frequent Commits
```bash
# Good: Each feature = 1 commit = 1 deployment
git commit -m "feat: Add user authentication"

# Bad: Multiple features in 1 commit
git commit -m "Multiple changes"
```

### 2. Meaningful Commit Messages
```bash
# ArgoCD shows commit message in UI
git commit -m "fix: Resolve memory leak in backend #123"
```

### 3. Use Git Tags for Releases
```bash
git tag -a v1.2.3 -m "Release v1.2.3"
git push --tags

# Reference in values.yaml
image:
  tag: v1.2.3
```

### 4. Separate Helm Values Per Environment
```
values.yaml           # Base config
values-dev.yaml       # Dev overrides
values-prod.yaml      # Prod overrides (different resources, replicas)
```

### 5. Enable Notifications
Configure ArgoCD to send alerts:
```yaml
# On sync failures, send to Slack/Teams
notifications:
  - on-sync-failed
  - on-health-degraded
```

## Troubleshooting

### Sync Stuck
```bash
# Terminate current sync
argocd app terminate-op microservices-app

# Retry
argocd app sync microservices-app
```

### Out of Sync
```bash
# Force sync (ignore cache)
argocd app sync microservices-app --force

# Hard refresh
argocd app get microservices-app --hard-refresh
```

### Manual Changes Reverted
This is **expected behavior** with `selfHeal: true`.
To make permanent changes:
1. Update Git repository
2. Push changes
3. Let ArgoCD sync

## Security Considerations

### 1. Image Signature Verification
Kyverno policy verifies Cosign signatures:
```yaml
# Before pod starts, Kyverno checks:
- Image signature valid?
- Signed by trusted key?
- No tampering detected?
```

### 2. Git Commit Signing
Use GPG-signed commits for trust:
```bash
git commit -S -m "Signed commit"
```

### 3. RBAC
Limit who can:
- Trigger manual syncs
- Override sync policies
- Delete applications

## Conclusion

ArgoCD provides:
- ✅ Automated deployment
- ✅ Git-based rollbacks
- ✅ Health monitoring
- ✅ Audit trail
- ✅ Consistency across environments

The loop closes:
```
Code → Build → Sign → Update Git → ArgoCD Sync → Deploy
```

Every deployment is traceable to a Git commit!
