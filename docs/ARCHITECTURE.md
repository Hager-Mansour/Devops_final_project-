# Enterprise DevSecOps Architecture

## 🏗️ Overall Architecture

### High-Level Architecture Overview

This architecture implements a production-grade DevSecOps pipeline leveraging Azure DevOps for CI/CD orchestration and AWS EKS for container orchestration. The design follows security-by-design principles with multiple security gates throughout the software delivery lifecycle.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          AZURE DEVOPS                                   │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐     │
│  │  Azure Repos     │  │  Azure Pipelines │  │  Azure Artifacts │     │
│  │  - Infra Repo    │  │  - CI Pipeline   │  │  - Helm Charts   │     │
│  │  - App Repo      │  │  - CD Pipeline   │  │  - Policies      │     │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘     │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
         ┌──────────▼──────┐   ┌───▼────────┐   ┌─▼──────────────┐
         │  Security Gates │   │   Build    │   │   GitOps Sync  │
         │  - SAST         │   │   Images   │   │   Update Helm  │
         │  - Checkov      │   │   - ECR    │   │   Values       │
         │  - Trivy        │   │   Push     │   └────────────────┘
         │  - Hadolint     │   └────────────┘
         └─────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                              AWS CLOUD                                  │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────┐      │
│  │                      VPC (10.0.0.0/16)                      │      │
│  │                                                              │      │
│  │  ┌──────────────────────────┐  ┌──────────────────────────┐│      │
│  │  │   Public Subnets         │  │   Private Subnets        ││      │
│  │  │   - NAT Gateway          │  │   - EKS Nodes            ││      │
│  │  │   - ALB                  │  │   - Application Pods     ││      │
│  │  │   - Bastion (optional)   │  │   - Argo CD              ││      │
│  │  └──────────────────────────┘  └──────────────────────────┘│      │
│  │                                                              │      │
│  │  ┌──────────────────────────────────────────────────────┐  │      │
│  │  │          EKS Cluster (Kubernetes 1.28+)              │  │      │
│  │  │  ┌────────────┐  ┌────────────┐  ┌────────────┐     │  │      │
│  │  │  │  Namespace │  │  Namespace │  │  Namespace │     │  │      │
│  │  │  │    argocd  │  │    prod    │  │    dev     │     │  │      │
│  │  │  │            │  │            │  │            │     │  │      │
│  │  │  │ ┌────────┐ │  │ ┌────────┐ │  │ ┌────────┐ │     │  │      │
│  │  │  │ │Argo CD │ │  │ │Frontend│ │  │ │Frontend│ │     │  │      │
│  │  │  │ │Server  │ │  │ │Backend │ │  │ │Backend │ │     │  │      │
│  │  │  │ └────────┘ │  │ │Ingress │ │  │ │Ingress │ │     │  │      │
│  │  │  └────────────┘  └────────────┘  └────────────┘     │  │      │
│  │  └──────────────────────────────────────────────────────┘  │      │
│  └─────────────────────────────────────────────────────────────┘      │
│                                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                │
│  │     IAM      │  │     ECR      │  │  CloudWatch  │                │
│  │  - IRSA      │  │  - Images    │  │  - Logs      │                │
│  │  - Policies  │  │  - Scanning  │  │  - Metrics   │                │
│  └──────────────┘  └──────────────┘  └──────────────┘                │
└─────────────────────────────────────────────────────────────────────────┘
```

### Component Breakdown

#### Azure DevOps Components

**1. Azure Repos**
- **Infrastructure Repository**: Contains Terraform and Ansible code
- **Application Repository**: Contains application code, Dockerfiles, and Helm charts
- Branch protection policies enforced
- Code review requirements

**2. Azure Pipelines**
- **PR Validation Pipeline**: Runs on every pull request
- **Infrastructure Pipeline**: Terraform + Ansible deployment
- **Application CI/CD Pipeline**: Build, scan, push, and GitOps sync
- Service connections to AWS (OIDC-based)

**3. Azure Artifacts**
- Helm chart repository (optional)
- Policy compliance artifacts
- Security scan reports

#### AWS Components

**1. Networking Layer**
- **VPC**: Isolated network (10.0.0.0/16)
- **Public Subnets**: For ALB, NAT Gateway
- **Private Subnets**: For EKS nodes (multi-AZ)
- **Security Groups**: Least-privilege access
- **Network ACLs**: Additional defense layer

**2. Compute Layer**
- **EKS Cluster**: Managed Kubernetes control plane
- **Managed Node Groups**: Auto-scaled worker nodes
- **IAM Roles for Service Accounts (IRSA)**: Pod-level IAM permissions
- **Launch Templates**: Node configuration and security

**3. Storage & Registry**
- **ECR**: Private Docker image registry
- **S3**: Terraform state, logs, backups
- **DynamoDB**: Terraform state locking

**4. Monitoring & Logging**
- **CloudWatch Logs**: Centralized logging
- **CloudWatch Metrics**: Custom and system metrics
- **CloudWatch Alarms**: Proactive alerting
- **Container Insights**: EKS-specific metrics

**5. Security Services**
- **IAM**: Fine-grained access control
- **AWS Secrets Manager**: Sensitive data storage
- **KMS**: Encryption key management
- **GuardDuty**: Threat detection (optional)

---

## 🔧 Toolchain Justification

### CI/CD Platform: Azure DevOps

**Why Azure DevOps?**
- **Enterprise-grade**: Mature platform with enterprise support
- **Integrated tooling**: Repos, Pipelines, Artifacts in one platform
- **Flexibility**: Works seamlessly with multi-cloud (AWS in this case)
- **YAML Pipelines**: Infrastructure-as-Code for CI/CD
- **Security**: Built-in secrets management, service connections
- **Hybrid capability**: Can work with on-prem and cloud agents

### Container Orchestration: AWS EKS

**Why EKS?**
- **Managed Control Plane**: AWS manages Kubernetes masters
- **AWS Integration**: Native integration with IAM, VPC, ALB, CloudWatch
- **Security**: Automatic security patches, encrypted etcd
- **Scalability**: Auto-scaling node groups
- **Compliance**: Meets enterprise compliance requirements
- **IRSA**: Pod-level IAM roles for least privilege

### Infrastructure as Code: Terraform

**Why Terraform?**
- **Multi-cloud support**: Industry standard for IaC
- **State management**: Remote state with locking
- **Modular design**: Reusable modules
- **Large ecosystem**: Extensive provider support
- **Plan before apply**: Preview changes before execution
- **Security scanning**: Native support for Checkov, tfsec

### Configuration Management: Ansible

**Why Ansible?**
- **Agentless**: SSH-based, no agents required
- **Post-provisioning**: Perfect for Kubernetes addons
- **Idempotent**: Safe to run multiple times
- **YAML-based**: Easy to read and maintain
- **Extensive modules**: Including Kubernetes/Helm modules

### GitOps: Argo CD

**Why Argo CD?**
- **Declarative GitOps**: Git as single source of truth
- **Kubernetes-native**: Designed specifically for K8s
- **Automated sync**: Continuous deployment
- **Rollback capability**: Easy to revert changes
- **Multi-cluster**: Can manage multiple clusters
- **RBAC integration**: Fine-grained access control
- **Health monitoring**: Application health checks

### Security Tools

| Tool | Purpose | Stage |
|------|---------|-------|
| **Checkov** | IaC security scanning | Infrastructure CI |
| **tfsec** | Terraform-specific security | Infrastructure CI |
| **ansible-lint** | Ansible playbook linting | Infrastructure CI |
| **Hadolint** | Dockerfile linting | Application CI |
| **Trivy** | Container image vulnerability scanning | Application CI/CD |
| **Cosign** | Container image signing | Application CD |
| **Syft** | SBOM generation | Application CD |
| **OWASP Dependency-Check** | Dependency vulnerability scanning | Application CI |

---

## 🔒 Security Trust Boundaries

### Trust Boundary 1: Developer Workstation → Azure Repos
**Controls:**
- MFA enforced for all developers
- Branch protection policies
- Required code reviews
- Commit signing (optional but recommended)
- No direct commits to main/master

### Trust Boundary 2: Azure Repos → Azure Pipelines
**Controls:**
- PR validation pipeline (automated gates)
- Security scans before merge
- Manual approval for infrastructure changes
- Service principal with least privilege
- Pipeline permissions restricted

### Trust Boundary 3: Azure Pipelines → AWS
**Controls:**
- OIDC-based authentication (no long-lived credentials)
- Service connection with specific role assumption
- AWS IAM roles with least privilege
- Temporary credentials only
- Audit logging enabled

### Trust Boundary 4: Azure Pipelines → ECR
**Controls:**
- Image scanning before push
- Image signing with Cosign
- SBOM attached to images
- Private registry only
- Immutable tags

### Trust Boundary 5: Argo CD → EKS
**Controls:**
- Argo CD runs in dedicated namespace
- RBAC for Argo CD service account
- Git repository credentials via secrets
- Sync policies (automated vs manual)
- Health checks before promotion

### Trust Boundary 6: EKS → AWS Services
**Controls:**
- IRSA for pod-level permissions
- No node-level AWS credentials
- Security groups restrict pod communication
- Network policies enforce segmentation
- Secrets stored in AWS Secrets Manager/K8s secrets

### Trust Boundary 7: External Users → Application
**Controls:**
- ALB with WAF (optional)
- TLS termination
- Ingress controllers with authentication
- Rate limiting
- DDoS protection via AWS Shield

---

## 🔄 Data Flow

### Development to Production Flow

```
1. Developer pushes code to feature branch
   ↓
2. PR created → PR Validation Pipeline triggered
   - Code linting
   - Security scanning
   - Unit tests
   ↓
3. Code review + approval
   ↓
4. Merge to main branch → Main Pipeline triggered
   ↓
5. Build Docker images
   ↓
6. Security scan images (Trivy)
   ↓
7. Sign images (Cosign) + Generate SBOM (Syft)
   ↓
8. Push to ECR
   ↓
9. Update Helm values with new image tags
   ↓
10. Commit Helm changes back to repo
   ↓
11. Argo CD detects change (auto-sync or manual)
   ↓
12. Argo CD applies changes to EKS
   ↓
13. Health checks validate deployment
   ↓
14. Monitoring & alerts active
```

---

## 🏢 Environment Strategy

### Environments

| Environment | Purpose | Approval | Auto-sync |
|-------------|---------|----------|-----------|
| **dev** | Development testing | None | Yes |
| **staging** | Pre-production validation | Team lead | Yes |
| **prod** | Production workloads | Change board | Manual |

### Environment Isolation

- **Namespace-based**: Each environment in separate K8s namespace
- **Resource quotas**: Prevent resource exhaustion
- **Network policies**: Restrict cross-namespace communication
- **RBAC**: Environment-specific permissions

---

## 📊 High Availability & Disaster Recovery

### High Availability
- **Multi-AZ deployment**: Nodes across 3 availability zones
- **Pod Disruption Budgets**: Minimum available pods during updates
- **Horizontal Pod Autoscaling**: Scale based on metrics
- **Cluster Autoscaling**: Add/remove nodes as needed
- **Health checks**: Liveness and readiness probes

### Disaster Recovery
- **Terraform state backup**: S3 versioning enabled
- **Configuration backup**: Git as single source of truth
- **Cluster backup**: Velero for K8s resources (optional)
- **Database backups**: Automated snapshots
- **RTO/RPO targets**: Documented and tested

---

## 🎯 Why This Architecture Stands Out

### For Interviews

**1. Enterprise-Grade**
- Not a toy project; production-ready patterns
- Follows industry best practices
- Multi-layered security approach

**2. Cloud-Native**
- Kubernetes-native design
- GitOps methodology
- Immutable infrastructure

**3. Security-First**
- Security at every stage (shift-left)
- Supply chain security (SBOM, signing)
- Zero-trust principles (IRSA, least privilege)

**4. Automation**
- Fully automated pipelines
- Infrastructure as Code
- Self-healing capabilities

**5. Observability**
- Comprehensive monitoring
- Centralized logging
- Proactive alerting

**6. Scalability**
- Auto-scaling capabilities
- Multi-environment support
- Multi-region ready (with modifications)

**7. Best Practices**
- 12-Factor App principles
- Microservices architecture
- GitOps deployment model
