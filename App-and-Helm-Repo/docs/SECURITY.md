# DevSecOps Security Summary

## Overview

This document explains the complete security implementation across the CI/CD pipeline and Kubernetes deployment.

## Security Architecture

```
┌───────────────────────────────────────────────────────────────────┐
│                     CI Pipeline (Build Time)                       │
├───────────────────────────────────────────────────────────────────┤
│  1. Code Scan        → Static analysis                            │
│  2. Dependency Scan  → CVE detection                              │
│  3. Docker Build     → Multi-stage builds                         │
│  4. Image Scan       → Trivy vulnerability scan                   │
│  5. SBOM Generation  → Transparency (Syft)                        │
│  6. Image Signing    → Provenance (Cosign)                        │
└────────────────────────────┬──────────────────────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │   ECR Registry │
                    │  Signed Images │
                    └────────┬───────┘
                             │
                             ▼
┌───────────────────────────────────────────────────────────────────┐
│                    CD Pipeline (Deploy Time)                       │
├───────────────────────────────────────────────────────────────────┤
│  7. GitOps Commit   → Auditable changes                           │
│  8. ArgoCD Sync     → Declarative deployment                      │
│  9. Kyverno Admit   → Policy enforcement                          │
│  10. Signature Check → Verify Cosign signature                     │
│  11. Pod Deploy     → Least privilege, read-only FS               │
│  12. Network Policy → Segment traffic                             │
└───────────────────────────────────────────────────────────────────┘
```

## CI Security (Build Pipeline)

### 1. Multi-Stage Docker Builds

**Purpose**: Minimize attack surface

**Implementation**:
```dockerfile
# Stage 1: Build
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Runtime (smaller, no build tools)
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
USER node  # Non-root user
CMD ["node", "server.js"]
```

**Benefits**:
- ✅ No build tools in final image
- ✅ Smaller image size (less vulnerabilities)
- ✅ Non-root user

### 2. Trivy Vulnerability Scanning

**Purpose**: Detect known CVEs in images

**Pipeline Stage**:
```yaml
- task: Bash@3
  displayName: 'Scan Frontend Image'
  inputs:
    script: |
      trivy image \
        --severity HIGH,CRITICAL \
        --exit-code 1 \
        $(ECR_REGISTRY)/$(FRONTEND_REPO):$(IMAGE_TAG)
```

**What Trivy Scans**:
- OS packages (Alpine, Debian, etc.)
- Application dependencies (npm, pip, Go modules)
- Known CVEs from NVD database
- Misconfigurations (Dockerfile best practices)

**Failure Behavior**:
- `--exit-code 1`: Pipeline fails if HIGH/CRITICAL found
- Prevents deploying vulnerable images

### 3. Dependency Scanning

**Purpose**: Find vulnerabilities in app dependencies

**Python (Backend)**:
```yaml
trivy fs --scanners vuln backend/requirements.txt
```

**JavaScript (Frontend)**:
```yaml
trivy fs --scanners vuln frontend/package.json
```

**Checks**:
- Known vulnerable versions
- Outdated dependencies
- License compliance issues

### 4. Image Signing with Cosign

**Purpose**: Ensure image provenance and prevent tampering

**Signing Process**:
```bash
# Generate key pair (done once)
cosign generate-key-pair

# Sign image in pipeline
cosign sign --key cosign.key \
  $(ECR_REGISTRY)/$(FRONTEND_REPO):$(IMAGE_TAG)
```

**What Gets Signed**:
- Image digest (SHA256 hash)
- Timestamp
- Metadata (build ID, commit SHA)

**Signature Storage**:
- Stored in ECR as separate tag
- Example: `sha256-abc123.sig`

**Verification** (in Kubernetes):
```yaml
# Kyverno policy verifies before pod starts
apiVersion: kyverno.io/v1
kind: ClusterPolicy
spec:
  rules:
    - name: verify-image
      verifyImages:
        - imageReferences:
            - "*.dkr.ecr.*.amazonaws.com/*:*"
          attestors:
            - count: 1
              entries:
                - keys:
                    publicKeys: |-
                      -----BEGIN PUBLIC KEY-----
                      ...
                      -----END PUBLIC KEY-----
```

### 5. SBOM Generation with Syft

**Purpose**: Software Bill of Materials for supply chain transparency

**Generation**:
```bash
syft $(ECR_REGISTRY)/$(FRONTEND_REPO):$(IMAGE_TAG) \
  -o spdx-json \
  > frontend-sbom.spdx.json
```

**SBOM Contains**:
- All packages in image
- Version numbers
- Licenses
- Dependencies tree

**Use Cases**:
- Audit software components
- Track vulnerable packages
- License compliance
- Incident response

**Signing SBOM**:
```bash
cosign sign-blob --key cosign.key \
  frontend-sbom.spdx.json
```

### 6. Secrets Management

**Problem**: Never commit secrets to Git

**Solution**: Azure Key Vault + Variable Groups

```yaml
variables:
  - group: AWS-Credentials  # From Azure Key Vault
  - group: Cosign-Keys      # Cosign keys
```

**In Kubernetes**:
```yaml
# Use External Secrets Operator (future enhancement)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: postgres-secret
spec:
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: postgres-secret
  data:
    - secretKey: password
      remoteRef:
        key: postgres-password
```

## CD Security (Deployment)

### 7. GitOps Audit Trail

**Purpose**: Every change is traceable

**Benefits**:
- ✅ Git commit shows WHO changed WHAT and WHEN
- ✅ Can revert any change via `git revert`
- ✅ Compliance audit trail
- ✅ No direct kubectl access needed

**Example Commit**:
```
commit abc123def456
Author: CI Pipeline <ci@example.com>
Date:   2026-02-07 10:15:23

ci: Update image tags to sha256-xyz789

- Frontend: registry/frontend:sha256-xyz789
- Backend: registry/backend:sha256-xyz789

Build: 12345
Trivy: passed
Cosign: signed
```

### 8. Kyverno Policy Enforcement

**Purpose**: Admission control - enforce security policies

**Installed Policies**:

#### Policy 1: Block `:latest` Tag
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
spec:
  validationFailureAction: enforce
  rules:
    - name: require-image-tag
      match:
        resources:
          kinds:
            - Pod
      validate:
        message: "Using ':latest' tag is not allowed"
        pattern:
          spec:
            containers:
              - image: "!*:latest"
```

#### Policy 2: Require Resource Limits
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  rules:
    - name: validate-resources
      validate:
        message: "CPU and memory limits required"
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    memory: "?*"
                    cpu: "?*"
```

#### Policy 3: Verify Image Signatures
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-cosign-signatures
spec:
  rules:
    - name: verify-signature
      verifyImages:
        - imageReferences:
            - "860973283177.dkr.ecr.us-east-1.amazonaws.com/*:*"
          attestors:
            - count: 1
              entries:
                - keys:
                    publicKeys: |-
                      {{ COSIGN_PUBLIC_KEY }}
```

**Enforcement**:
- Pods without valid signature: **REJECTED**
- Pods with `:latest` tag: **REJECTED**
- Pods without resource limits: **REJECTED**

### 9. Pod Security Context

**Purpose**: Least privilege for containers

**Helm Template**:
```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true  # Immutable filesystem
  capabilities:
    drop:
      - ALL
```

**Benefits**:
- ✅ Containers run as non-root user
- ✅ Cannot escalate privileges
- ✅ Read-only filesystem (prevents malware persistence)
- ✅ No dangerous capabilities

### 10. Network Policies

**Purpose**: Segment pod-to-pod traffic

**Example**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-network-policy
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow only from frontend
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - port: 5000
  egress:
    # Allow only to postgres
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - port: 5432
    # Allow DNS
    - to:
        - namespaceSelector: {}
      ports:
        - port: 53
          protocol: UDP
```

**Result**:
- Frontend can talk to Backend ✅
- Backend can talk to Database ✅
- Random pod cannot access Backend ❌

### 11. Database Security

**Credentials**:
```yaml
# Stored in Kubernetes Secret (base64)
# In production: use AWS Secrets Manager
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
type: Opaque
data:
  postgres-password: <base64>
  database-url: <base64>
```

**Persistent Storage**:
```yaml
# StatefulSet ensures data persistence
volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: gp2
      resources:
        requests:
          storage: 10Gi
```

**Backup Strategy**:
```bash
# Scheduled CronJob for PostgreSQL backups
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: postgres:15
              command:
                - /bin/sh
                - -c
                - pg_dump $DATABASE_URL | gzip > /backup/backup-$(date +%Y%m%d).sql.gz
              env:
                - name: DATABASE_URL
                  valueFrom:
                    secretKeyRef:
                      name: postgres-secret
                      key: database-url
              volumeMounts:
                - name: backup-storage
                  mountPath: /backup
          volumes:
            - name: backup-storage
              persistentVolumeClaim:
                claimName: postgres-backup-pvc
```

## Supply Chain Security

### Attack Vector Prevention

| Attack                      | Prevention Mechanism                           |
| --------------------------- | ---------------------------------------------- |
| **Malicious base image**    | Trivy scan fails if vulnerabilities detected   |
| **Tampered image**          | Cosign signature verification in Kyverno       |
| **Vulnerable dependency**   | Dependency scan in CI pipeline                 |
| **Unsigned image deployed** | Kyverno blocks unsigned images                 |
| **Privileged pod**          | Pod Security Standards enforce least privilege |
| **Lateral movement**        | Network Policies restrict traffic              |
| **Hardcoded secrets**       | Secrets in Kubernetes Secrets/Azure Key Vault  |

### Supply Chain Flow

```
Developer
    │
    ├─► Commits code to Git
    │
    ▼
CI Pipeline
    │
    ├─► Builds image
    ├─► Scans for vulnerabilities (Trivy)
    ├─► Fails if HIGH/CRITICAL found ← SECURITY GATE 1
    ├─► Generates SBOM (Syft)
    ├─► Signs image (Cosign) ← SECURITY GATE 2
    │
    ▼
ECR Registry
    │
    ├─► Stores signed image
    │
    ▼
GitOps (ArgoCD)
    │
    ├─► Detects Helm change
    ├─► Syncs to Kubernetes
    │
    ▼
Kyverno
    │
    ├─► Verifies image signature ← SECURITY GATE 3
    ├─► Blocks if signature invalid
    ├─► Enforces pod security policies
    │
    ▼
Kubernetes
    │
    └─► Deploys pod with least privilege
```

## Compliance & Auditing

### Audit Logs

**Kubernetes Audit Logs**:
```
/var/log/kubernetes/audit/audit.log
```

**Captured Events**:
- kubectl commands
- API server requests
- Who created/deleted resources
- Policy violations

**CloudWatch Integration**:
```bash
aws eks update-cluster-config \
  --name devsecops-dev-eks \
  --logging '{"clusterLogging":[{"types":["audit"],"enabled":true}]}'
```

### Policy Violations

Kyverno logs all violations:
```bash
kubectl get policyreport -A
```

Example report:
```yaml
apiVersion: wgpolicyk8s.io/v1alpha2
kind: PolicyReport
metadata:
  name: polr-ns-dev
results:
  - message: "validation error: Using ':latest' tag is not allowed"
    policy: disallow-latest-tag
    result: fail
    timestamp:
      nanos: 0
      seconds: 1675789123
```

## Incident Response

### If Vulnerability Found Post-Deployment

1. **Identify affected images**:
   ```bash
   trivy image --severity HIGH,CRITICAL $(ECR_REGISTRY)/app:tag
   ```

2. **Review SBOM** to find vulnerable package:
   ```bash
   cat frontend-sbom.spdx.json | jq '.packages[] | select(.name=="vulnerable-lib")'
   ```

3. **Patch & rebuild**:
   ```bash
   # Update dependency
   npm update vulnerable-lib
   
   # Trigger pipeline
   git commit -m "fix: Update vulnerable-lib to v2.0"
   git push
   ```

4. **Emergency rollback**:
   ```bash
   # Revert to previous safe version
   git revert HEAD
   git push
   
   # Or via ArgoCD
   argocd app rollback microservices-app
   ```

## Security Checklist

### CI Pipeline
- [x] Docker multi-stage builds
- [x] Trivy image scanning
- [x] Dependency scanning
- [x] SBOM generation
- [x] Image signing with Cosign
- [x] Signed SBOMs
- [x] No secrets in code

### CD Pipeline
- [x] GitOps with ArgoCD
- [x] Kyverno policy enforcement
- [x] Image signature verification
- [x] Pod security contexts
- [x] Network policies
- [x] Secrets management
- [x] Audit logging

## Best Practices

1. **Never disable signature verification** in production
2. **Regularly update base images** to patch OS vulnerabilities
3. **Monitor Kyverno policy reports** for violations
4. **Rotate Cosign keys** annually
5. **Archive SBOMs** for compliance
6. **Test disaster recovery** (database restore)
7. **Review audit logs** weekly

## Conclusion

### Security Applied in CI
- ✅ Vulnerability scanning (Trivy)
- ✅ Dependency checks
- ✅ Image signing (Cosign)
- ✅ SBOM generation (Syft)
- ✅ Build-time secrets management

### Security Applied in CD
- ✅ GitOps audit trail
- ✅ Policy enforcement (Kyverno)
- ✅ Signature verification
- ✅ Least privilege pods
- ✅ Network segmentation
- ✅ Runtime secrets management

### Supply Chain Security Flow
```
Code → Build → Scan → Sign → SBOM → Verify → Deploy
  ✓      ✓      ✓      ✓      ✓       ✓       ✓
```

**Every layer has a security control. Defense in depth!**
