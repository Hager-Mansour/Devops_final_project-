# Microservices Application - Production DevSecOps

> **Production-ready Helm chart + Azure DevOps CI/CD pipelines with complete DevSecOps integration**

## 📁 Repository Structure

```
project/
├── frontend/                      # React frontend source code
│   └── Dockerfile
├── backend/                       # Flask backend source code
│   └── Dockerfile
├── helm/app/                     # Production Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── secrets.yaml
│       ├── postgres-statefulset.yaml
│       ├── postgres-service.yaml
│       ├── backend-deployment.yaml
│       ├── backend-service.yaml
│       ├── frontend-deployment.yaml
│       ├── frontend-service.yaml
│       └── ingress.yaml
├── .azure-pipelines/             # CI/CD Pipelines
│   ├── pr-validation.yml         # PR validation pipeline
│   └── azure-pipelines-main.yml  # Main release pipeline
├── docs/                         # Documentation
│   ├── GITOPS.md                 # GitOps with ArgoCD explained
│   ├── MONITORING.md             # CloudWatch & logging
│   └── SECURITY.md               # DevSecOps summary
├── argocd-application.yaml       # ArgoCD app manifest
└── docker-compose.yml            # Local development

```

## 🎯 Features

### Helm Chart - Production!
- ✅ **PostgreSQL StatefulSet** with persistent storage (NOT Bitnami chart)
- ✅ **Frontend & Backend** deployments with health checks
- ✅ **Secrets management** for database credentials
- ✅ **Resource limits** enforced
- ✅ **Security contexts** (non-root, read-only filesystem)
- ✅ **Ingress** support for AWS Load Balancer Controller
- ✅ **GitOps-friendly** values structure

### CI/CD Pipelines
1. **PR Validation Pipeline** (`pr-validation.yml`)
   - Helm lint
   - Template rendering validation
   - YAML syntax checks
   - Trivy filesystem scan
   - NO Docker build/push

2. **Main Release Pipeline** (`azure-pipelines-main.yml`)
   - Prerequisites & AWS validation
   - Build frontend & backend images
   - **Trivy** vulnerability scanning (fails on HIGH/CRITICAL)
   - Push to **AWS ECR**
   - **Cosign** image signing
   - **Syft** SBOM generation
   - Update Helm values with Git SHA tags
   - Commit & push to Git (GitOps)
   - 8 automated stages

### DevSecOps Integration
- 🔒 **Trivy** vulnerability scanning
- 🔑 **Cosign** image signing & verification
- 📦 **Syft** SBOM (Software Bill of Materials)
- 🛡️ **Kyverno** policy enforcement in K8s
- 📝 **GitOps** with ArgoCD
- 📊 **CloudWatch** monitoring
- 🔐 **Secrets** in Azure Key Vault

## 🚀 Quick Start

### Prerequisites
- AWS EKS cluster running
- ArgoCD installed on cluster
- Azure DevOps organization
- AWS ECR repositories created

### 1. Setup Azure DevOps Variable Groups

Create 4 variable groups in Azure DevOps:

#### Variable Group: `AWS-Credentials`
```
AWS_ACCESS_KEY_ID=<your-access-key>
AWS_SECRET_ACCESS_KEY=<your-secret-key>  # Mark as secret
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=860973283177
```

#### Variable Group: `Docker-Registry`
```
ECR_REGISTRY=860973283177.dkr.ecr.us-east-1.amazonaws.com
FRONTEND_REPO=devsecops-dev-frontend
BACKEND_REPO=devsecops-dev-backend
```

#### Variable Group: `Cosign-Keys`
```
COSIGN_PRIVATE_KEY=<paste private key>  # Mark as secret
COSIGN_PUBLIC_KEY=<paste public key>
COSIGN_PASSWORD=<key password>          # Mark as secret
```

#### Variable Group: `Git-Credentials`
```
GIT_PAT=<Azure DevOps PAT>  # Mark as secret
GIT_EMAIL=azure-pipelines@devsecops.local
GIT_USERNAME=Azure DevOps Pipeline
```

### 2. Import Pipelines to Azure DevOps

```bash
# In Azure DevOps project:
# Pipelines → New Pipeline → Azure Repos Git → Select repo

# Add PR validation pipeline
# Name: "PR Validation"
# YAML: .azure-pipelines/pr-validation.yml

# Add main release pipeline
# Name: "Main Release"
# YAML: .azure-pipelines/azure-pipelines-main.yml
```

### 3. Deploy ArgoCD Application

```bash
# Apply ArgoCD Application manifest
kubectl apply -f argocd-application.yaml -n argocd

# Verify application created
argocd app get microservices-app
```

### 4. Trigger First Deployment

```bash
# Push to main branch
git add .
git commit -m "feat: Initial deployment"
git push origin main

# Pipeline automatically:
# 1. Builds images
# 2. Scans with Trivy
# 3. Signs with Cosign
# 4. Generates SBOMs
# 5. Updates Helm values
# 6. Commits to Git

# ArgoCD automatically:
# 1. Detects Git change
# 2. Syncs deployment
# 3. Verifies signatures (Kyverno)
# 4. Deploys pods
```

## 📊 Pipeline Flow

```
┌──────────────┐
│  Code Push   │
│  to main     │
└──────┬───────┘
       │
       ▼
┌──────────────────────────────────────┐
│  Azure DevOps Pipeline Stages        │
├──────────────────────────────────────┤
│  1. Prerequisites Check              │
│     - Install tools                  │
│     - Verify AWS access              │
│                                      │
│  2. Build Images                     │
│     - Frontend Docker build          │
│     - Backend Docker build           │
│                                      │
│  3. Security Scanning                │
│     - Trivy image scan               │
│     - Dependency scan                │
│     - Fail on HIGH/CRITICAL          │
│                                      │
│  4. Push to ECR                      │
│     - Login to AWS ECR               │
│     - Push frontend:sha256-xxx       │
│     - Push backend:sha256-xxx        │
│                                      │
│  5. Sign Images (Cosign)             │
│     - Sign frontend image            │
│     - Sign backend image             │
│     - Verify signatures              │
│                                      │
│  6. Generate SBOM (Syft)             │
│     - Generate frontend SBOM         │
│     - Generate backend SBOM          │
│     - Sign SBOMs                     │
│                                      │
│  7. Update Helm Values               │
│     - Update values.yaml tags        │
│     - Git commit                     │
│     - Git push                       │
│                                      │
│  8. Summary                          │
│     - Print deployment info          │
└──────────────┬───────────────────────┘
               │
               │ Git commit pushed
               ▼
       ┌───────────────┐
       │  Git Repo     │
       │  values.yaml  │
       │  updated      │
       └───────┬───────┘
               │
               │ ArgoCD polls (3min)
               ▼
       ┌───────────────┐
       │    ArgoCD     │
       │  - Detects Δ  │
       │  - Syncs      │
       └───────┬───────┘
               │
               ▼
       ┌───────────────┐
       │    Kyverno    │
       │  - Verify sig │
       │  - Check pod  │
       └───────┬───────┘
               │
               ▼
       ┌───────────────┐
       │  Kubernetes   │
       │  Pods Running │
       └───────────────┘
```

## 🔧 Helm Chart Details

### Values Structure

```yaml
frontend:
  image:
    repository: <ecr-url>/frontend
    tag: latest  # Updated by CI/CD
  replicaCount: 2
  resources:
    limits:
      cpu: 500m
      memory: 512Mi

backend:
  image:
    repository: <ecr-url>/backend
    tag: latest  # Updated by CI/CD
  replicaCount: 2
  env:
    FLASK_ENV: production
    DATABASE_URL_FROM_SECRET: true

postgresql:
  enabled: true
  image:
    repository: postgres
    tag: "15-alpine"
  persistence:
    enabled: true
    size: 10Gi
    storageClass: gp2
  database: microservices_db
  username: postgres
```

### PostgreSQL StatefulSet Features

- **Stable network identity**: Pod name never changes
- **Persistent storage**: Data survives pod restarts
- **Ordered deployment**: Pods start sequentially
- **Headless Service**: Direct pod-to-pod DNS
- **VolumeClaimTemplate**: Automatic PVC creation

### Wiring Components Together

**Backend → PostgreSQL**:
```yaml
# Backend deployment gets DB credentials from Secret
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: app-postgres-secret
        key: database-url
  - name: POSTGRES_HOST
    value: app-postgres  # Service name
```

**Frontend → Backend**:
```yaml
# Frontend deployment
env:
  - name: REACT_APP_API_URL
    value: "http://app-backend:5000/api"
  - name: BACKEND_SERVICE_HOST
    value: app-backend  # Service name
```

## 📝 Image Tagging Strategy

### Git SHA Tagging
Every build uses the **Git commit SHA** as the image tag:

```bash
# Azure Pipeline variable
IMAGE_TAG=$(Build.SourceVersion)  # Git SHA (40 chars)

# Images tagged as:
frontend:abc123def456...  
backend:abc123def456...
```

### Benefits
- ✅ **Immutable**: Same tag = same code
- ✅ **Traceable**: Can find exact commit
- ✅ **Rollback**: Revert to previous SHA
- ✅ **Audit**: Know what's deployed

### How Pipeline Updates Tags

```bash
# Pipeline automatically runs:
sed -i "s|tag:.*# Updated by CI/CD.*|tag: $(IMAGE_TAG)|" helm/app/values.yaml

# Then commits:
git commit -m "ci: Update image tags to $(IMAGE_TAG)"
git push
```

### ArgoCD Detects Change

```
Before:
  frontend:
    image:
      tag: sha256-old123

After:
  frontend:
    image:
      tag: sha256-new456  ← Change detected!

ArgoCD → Syncs → Deploys new pods
```

## 🔒 Security Features

### CI Security
1. **Trivy Scanning**: Blocks HIGH/CRITICAL vulnerabilities
2. **Dependency Scan**: Detects vulnerable packages
3. **Multi-stage Builds**: Minimal attack surface
4. **Cosign Signing**: Proves image provenance
5. **SBOM Generation**: Supply chain transparency

### CD Security
1. **Kyverno Policies**:
   - Blocks unsigned images
   - Blocks `:latest` tag
   - Requires resource limits
2. **Pod Security**:
   - Non-root user
   - Read-only filesystem
   - No privilege escalation
3. **Network Policies**: Segment traffic
4. **Secrets Management**: Never hardcoded

See [docs/SECURITY.md](docs/SECURITY.md) for complete details.

## 📊 Monitoring

- **CloudWatch Container Insights**: Cluster metrics
- **CloudWatch Logs**: Centralized logging
- **Fluent Bit**: Log shipping
- **Health Checks**: Liveness & readiness probes
- **Alarms**: CPU/memory/pod status alerts

See [docs/MONITORING.md](docs/MONITORING.md) for setup.

## 🔄 GitOps with ArgoCD

### Why GitOps?
- Git is single source of truth
- Automatic deployment
- Easy rollbacks (git revert)
- Audit trail
- No kubectl access needed

### How It Works
1. Developer pushes code
2. Pipeline builds & updates Helm values
3. ArgoCD detects Git change (polls every 3 min)
4. ArgoCD syncs to Kubernetes
5. Kyverno verifies signatures
6. Pods update with new images

See [docs/GITOPS.md](docs/GITOPS.md) for deep dive.

## 🧪 Local Development

### Run with Docker Compose
```bash
docker-compose up --build

# Access:
# Frontend: http://localhost:80
# Backend:  http://localhost:5000
# Database: localhost:5432
```

### Test Helm Chart Locally
```bash
# Lint
helm lint helm/app/

# Template rendering
helm template microservices-app helm/app/ \
  --values helm/app/values.yaml \
  --namespace dev

# Dry-run install
helm install microservices-app helm/app/ \
  --values helm/app/values.yaml \
  --namespace dev \
  --dry-run --debug
```

## 📚 Documentation

| Document                            | Description                          |
| ----------------------------------- | ------------------------------------ |
| [GITOPS.md](docs/GITOPS.md)         | ArgoCD workflow, rollback, promotion |
| [MONITORING.md](docs/MONITORING.md) | CloudWatch, logs, metrics, alarms    |
| [SECURITY.md](docs/SECURITY.md)     | CI/CD security, supply chain         |

## 🎓 Interview-Ready Points

### Helm Chart
- ✅ PostgreSQL as StatefulSet (not Bitnami)
- ✅ PersistentVolumeClaims
- ✅ Secrets for credentials
- ✅ Service discovery via DNS
- ✅ Health probes
- ✅ Resource limits

### CI/CD Pipeline
- ✅ 8-stage DevSecOps pipeline
- ✅ Git SHA image tagging
- ✅ Trivy fails on vulnerabilities
- ✅ Cosign signing & verification
- ✅ SBOM generation
- ✅ GitOps commit automation

### GitOps
- ✅ Declarative infrastructure
- ✅ Pull-based deployment
- ✅ Automatic sync
- ✅ Git-based rollback
- ✅ Audit trail

### Security
- ✅ Supply chain security (SBOM, signing)
- ✅ Policy enforcement (Kyverno)
- ✅ Least privilege pods
- ✅ Network segmentation
- ✅ Secrets management

## 🚨 Troubleshooting

### Pipeline Fails on Trivy Scan
```bash
# Image has HIGH/CRITICAL vulnerabilities
# Fix: Update base image or dependencies
```

### ArgoCD Not Syncing
```bash
# Check ArgoCD UI
argocd app get microservices-app

# Force sync
argocd app sync microservices-app --force
```

### Pod CrashLoopBackOff
```bash
# Check logs
kubectl logs -n dev <pod-name>

# Check events
kubectl describe pod -n dev <pod-name>

# Common: Database connection failed
# Fix: Verify postgres-secret exists
```

### Kyverno Blocks Deployment
```bash
# Check policy violations
kubectl get policyreport -n dev

# Common: Image not signed
# Fix: Ensure Cosign signing succeeded in pipeline
```

## 🏆 Best Practices Implemented

- ✅ Git as single source of truth
- ✅ Immutable infrastructure (Git SHA tags)
- ✅ Fail-fast on vulnerabilities
- ✅ Signed images only in production
- ✅ Secrets never in Git
- ✅ Declarative Helm charts
- ✅ Automated testing (Helm lint)
- ✅ Health checks for all pods
- ✅ Resource limits enforced
- ✅ Non-root containers
- ✅ Read-only filesystems
- ✅ Network policies

## 📄 License

MIT

---

**Built with**: Helm 3.14 | Kubernetes 1.35 | ArgoCD | Kyverno | Trivy | Cosign | Syft | Azure DevOps
