# Infrastructure Repository

## 📁 Repository Structure

```
infrastructure-repo/
├── README.md
├── terraform/
│   ├── backend.tf                 # S3 + DynamoDB backend configuration
│   ├── provider.tf                # AWS provider configuration
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Output values
│   ├── terraform.tfvars.example   # Example variable values
│   ├── modules/
│   │   ├── vpc/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   ├── eks/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   ├── iam/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   └── ecr/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── README.md
│   └── environments/
│       ├── dev/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── terraform.tfvars
│       └── prod/
│           ├── main.tf
│           ├── variables.tf
│           └── terraform.tfvars
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── hosts.yml
│   ├── playbooks/
│   │   ├── configure-eks.yml      # Main playbook
│   │   ├── install-argocd.yml     # Argo CD installation
│   │   ├── install-addons.yml     # K8s addons
│   │   └── harden-cluster.yml     # Security hardening
│   ├── roles/
│   │   ├── argocd/
│   │   │   ├── tasks/
│   │   │   ├── templates/
│   │   │   └── vars/
│   │   ├── aws-lb-controller/
│   │   │   ├── tasks/
│   │   │   ├── templates/
│   │   │   └── vars/
│   │   ├── metrics-server/
│   │   │   ├── tasks/
│   │   │   └── vars/
│   │   └── cluster-hardening/
│   │       ├── tasks/
│   │       └── templates/
│   └── group_vars/
│       └── all.yml
├── pipelines/
│   └── azure-pipelines-infra.yml  # Azure DevOps pipeline
└── scripts/
    ├── create-backend.sh           # Initialize Terraform backend
    └── validate-infra.sh           # Validation script
```

## 🎯 Purpose

This repository manages all AWS infrastructure and EKS cluster configuration using Infrastructure as Code (IaC) principles.

**Key Responsibilities:**
- Provision AWS VPC, subnets, and networking
- Deploy EKS cluster with managed node groups
- Configure IAM roles and policies
- Set up ECR for container images
- Install and configure Kubernetes addons
- Implement security hardening

---

## 🔧 Terraform Modules

### Module: VPC

**Path:** `terraform/modules/vpc/`

**Purpose:** Creates isolated VPC with public and private subnets across multiple availability zones.

**Resources:**
- VPC with DNS support
- Internet Gateway
- NAT Gateways (HA setup)
- Public subnets (for ALB, NAT)
- Private subnets (for EKS nodes)
- Route tables and associations
- Subnet tagging for EKS/ALB discovery

**Key Outputs:**
- `vpc_id`
- `private_subnet_ids`
- `public_subnet_ids`

### Module: EKS

**Path:** `terraform/modules/eks/`

**Purpose:** Deploys managed EKS cluster with secure configuration.

**Resources:**
- EKS cluster
- Managed node groups (multiple AZs)
- Cluster security group
- Node security group  
- OIDC provider for IRSA
- Launch templates
- Cluster addons (CoreDNS, kube-proxy, VPC CNI)

**Key Outputs:**
- `cluster_id`
- `cluster_endpoint`
- `cluster_certificate_authority`
- `oidc_provider_arn`

### Module: IAM

**Path:** `terraform/modules/iam/`

**Purpose:** Creates IAM roles and policies following least privilege.

**Resources:**
- EKS cluster role
- EKS node group role
- IRSA roles for:
  - AWS Load Balancer Controller
  - External DNS (optional)
  - Cluster Autoscaler
  - Argo CD (if AWS access needed)
- Policies with minimal permissions

**Key Outputs:**
- Role ARNs for each service

### Module: ECR

**Path:** `terraform/modules/ecr/`

**Purpose:** Creates private container registries with security scanning.

**Resources:**
- ECR repositories (frontend, backend)
- Image scanning on push
- Lifecycle policies
- Repository policies

**Key Outputs:**
- Repository URLs

---

## 📜 Ansible Configuration

### Playbook: configure-eks.yml

**Purpose:** Master playbook orchestrating all EKS configuration.

**Tasks:**
1. Update kubeconfig
2. Verify cluster connectivity
3. Install Argo CD
4. Install Kubernetes addons
5. Apply cluster hardening

### Playbook: install-argocd.yml

**Purpose:** Deploy Argo CD using Helm.

**Tasks:**
- Create argocd namespace
- Add Argo CD Helm repo
- Deploy Argo CD with custom values
- Configure initial admin password
- Expose Argo CD (LoadBalancer or NodePort)

### Playbook: install-addons.yml

**Purpose:** Install essential Kubernetes addons.

**Addons:**
- Metrics Server (for HPA)
- AWS Load Balancer Controller (for ALB/NLB)
- Cluster Autoscaler (optional)
- External DNS (optional)

### Playbook: harden-cluster.yml

**Purpose:** Apply security hardening configurations.

**Tasks:**
- Apply Pod Security Standards
- Configure Network Policies
- Set up RBAC restrictions
- Enable audit logging
- Configure secret encryption

---

## 🔒 Security Implementation

### Terraform Security Scanning

**Tools Used:**
1. **Checkov** - Multi-cloud IaC scanner
2. **tfsec** - Terraform-specific security scanner

**Checks Include:**
- Encryption at rest/in transit
- Public access restrictions
- IAM policy validation
- Security group rules
- Logging enablement
- Resource tagging

**Pipeline Integration:**
```yaml
- task: Bash@3
  displayName: 'Run Checkov'
  inputs:
    targetType: 'inline'
    script: |
      checkov -d terraform/ --framework terraform \
        --output junitxml --output-file-path checkov-report.xml
    
- task: PublishTestResults@2
  displayName: 'Publish Checkov Results'
  inputs:
    testResultsFormat: 'JUnit'
    testResultsFiles: 'checkov-report.xml'
```

### Ansible Security

**Tools Used:**
1. **ansible-lint** - Ansible playbook linting

**Checks Include:**
- Task naming conventions
- Deprecated module usage
- Security best practices
- Idempotency validation

**Secret Management:**
- Use Ansible Vault for sensitive data
- Never commit plain-text secrets
- Use AWS Secrets Manager integration

---

## 🚀 Azure DevOps Pipeline

### Pipeline Stages

**Stage 1: Validation**
- Terraform fmt check
- Terraform validate
- Checkov scanning
- tfsec scanning
- ansible-lint

**Stage 2: Plan**
- Terraform init
- Terraform plan
- Save plan artifact

**Stage 3: Approval**
- Manual approval gate (for prod)
- Review plan output

**Stage 4: Apply**
- Terraform apply
- Save outputs

**Stage 5: Configure**
- Run Ansible playbooks
- Configure EKS cluster
- Install addons

**Stage 6: Verify**
- Validate cluster health
- Check addon status
- Run smoke tests

### Environment Separation

**Development:**
- Auto-apply (no manual approval)
- Smaller instance types
- Minimal node count

**Production:**
- Manual approval required
- Production-grade instances
- High availability configuration

---

## 📋 Prerequisites

### Local Development
```bash
# Required tools
terraform >= 1.5.0
ansible >= 2.14.0
aws-cli >= 2.0
kubectl >= 1.28
helm >= 3.12
```

### AWS Requirements
- AWS account with appropriate permissions
- S3 bucket for Terraform state
- DynamoDB table for state locking
- IAM user/role for Azure DevOps service connection

### Azure DevOps Requirements
- Service connection to AWS
- Agent pool (Microsoft-hosted or self-hosted)
- Variable groups for secrets

---

## 🔧 Usage

### Initialize Terraform Backend

```bash
cd infrastructure-repo/scripts
./create-backend.sh
```

### Local Development

```bash
# Initialize Terraform
cd terraform/environments/dev
terraform init

# Plan changes
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan

# Configure EKS
cd ../../ansible
ansible-playbook playbooks/configure-eks.yml
```

### Pipeline Deployment

1. Push changes to feature branch
2. Create pull request
3. PR validation pipeline runs automatically
4. After approval, merge to main
5. Infrastructure pipeline triggers
6. Review plan output
7. Approve deployment (for prod)
8. Infrastructure deployed

---

## 📊 Outputs

After successful deployment:

```
cluster_endpoint = "https://xxxxx.eks.amazonaws.com"
cluster_name = "eks-prod-cluster"
ecr_frontend_url = "123456789.dkr.ecr.us-west-2.amazonaws.com/frontend"
ecr_backend_url = "123456789.dkr.ecr.us-west-2.amazonaws.com/backend"
argocd_url = "http://argocd.example.com"
```

---

## 🔄 Maintenance

### Updating Infrastructure
1. Modify Terraform code
2. Run `terraform plan` locally
3. Create PR with changes
4. Review and merge
5. Pipeline deploys changes

### Updating Cluster Configuration
1. Modify Ansible playbooks
2. Test in dev environment
3. Promote to production

### Disaster Recovery
- Terraform state backed up in S3 (versioned)
- EKS configuration in Git
- Regular backup testing
