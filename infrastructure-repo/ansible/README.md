# Ansible Configuration for EKS Cluster

This directory contains Ansible playbooks and roles for configuring the AWS EKS cluster after Terraform provisioning.

## 📁 Directory Structure

```
ansible/
├── ansible.cfg                    # Ansible configuration
├── inventory                      # Inventory file (localhost)
├── group_vars/
│   └── all.yml                   # Global variables
├── playbooks/
│   ├── configure-eks.yml         # Main orchestration playbook
│   ├── install-argocd.yml        # Argo CD installation
│   ├── install-addons.yml        # Kubernetes addons
│   └── harden-cluster.yml        # Security hardening
└── roles/
    ├── argocd/                   # Argo CD role
    ├── aws-lb-controller/        # AWS LB Controller role
    ├── metrics-server/           # Metrics Server role
    └── cluster-hardening/        # Security hardening role
```

## 🎯 Purpose

These Ansible playbooks configure the EKS cluster with:
- **Argo CD** for GitOps-based deployments
- **Kubernetes addons** (Metrics Server, AWS Load Balancer Controller, Cluster Autoscaler)
- **Security hardening** (Pod Security Standards, Network Policies, RBAC, Resource Quotas)

## 📋 Prerequisites

### Required Tools
```bash
ansible >= 2.14.0
kubectl >= 1.28
aws-cli >= 2.0
helm >= 3.12
```

### Required Ansible Collections
```bash
ansible-galaxy collection install kubernetes.core
ansible-galaxy collection install community.general
```

### AWS & EKS Requirements
- EKS cluster must be created (via Terraform)
- AWS credentials configured (`~/.aws/credentials` or environment variables)
- IAM roles for IRSA (created by Terraform):
  - AWS Load Balancer Controller role
  - Cluster Autoscaler role (optional)
  
### Environment Variables

Set these before running playbooks:

```bash
export CLUSTER_NAME="your-eks-cluster-name"
export LB_CONTROLLER_ROLE_ARN="arn:aws:iam::ACCOUNT:role/aws-lb-controller-role"
export CLUSTER_AUTOSCALER_ROLE_ARN="arn:aws:iam::ACCOUNT:role/cluster-autoscaler-role"  # Optional
export COSIGN_PUBLIC_KEY="$(cat cosign.pub)"  # Your Cosign public key for image verification
```

## 🚀 Usage

### 1. Install Required Ansible Collections

```bash
ansible-galaxy collection install kubernetes.core
ansible-galaxy collection install community.general
```

### 2. Update kubeconfig (if not already done)

```bash
aws eks update-kubeconfig --name your-cluster-name --region us-east-1
```

### 3. Run the Main Playbook

Run all configurations in sequence:

```bash
cd infrastructure-repo/ansible
ansible-playbook playbooks/configure-eks.yml
```

### 4. Run Individual Playbooks

You can also run playbooks individually:

```bash
# Install Argo CD only
ansible-playbook playbooks/install-argocd.yml

# Install addons only
ansible-playbook playbooks/install-addons.yml

# Apply security hardening only
ansible-playbook playbooks/harden-cluster.yml
```

## 📊 What Gets Installed

### Argo CD
- **Namespace**: `argocd`
- **Service Type**: LoadBalancer
- **Components**: Server, Repo Server, Application Controller, Notifications, ApplicationSet

### Kubernetes Addons
- **Metrics Server**: Enables HPA and `kubectl top` commands
- **AWS Load Balancer Controller**: Manages ALB/NLB for Ingress resources
- **Cluster Autoscaler**: Automatically scales node groups (optional)
- **Kyverno**: Policy engine for runtime security and compliance enforcement

### Security Hardening
- **Namespaces**: `dev`, `staging`, `prod`
- **Pod Security Standards**: `restricted` profile enforced
- **Resource Quotas**: Per-namespace CPU and memory limits
- **Network Policies**: Default deny ingress with same-namespace allowance
- **RBAC Roles**: Read-only developer roles
- **Kyverno Policies**: Runtime policy enforcement for images, resources, and compliance

## 🔒 Security Configuration

### Kyverno Policy Engine

Kyverno is deployed as a dynamic admission controller that enforces policies at runtime. The following policies are automatically applied:

#### 1. **Disallow Latest Tag** (Medium Severity)
- **Purpose**: Prevents use of `:latest` tag on container images
- **Scope**: `dev`, `staging`, `prod` namespaces
- **Action**: Enforce (blocks pod creation)
- **Rationale**: The `:latest` tag is mutable and can lead to unexpected behavior and security issues

#### 2. **Require Resource Limits** (Medium Severity)
- **Purpose**: Ensures all containers define CPU and memory requests/limits
- **Scope**: `dev`, `staging`, `prod` namespaces
- **Action**: Enforce (blocks pod creation)
- **Rationale**: Prevents resource exhaustion and improves cluster stability

#### 3. **Restrict Image Registries** (High Severity)
- **Purpose**: Only allows images from approved AWS ECR registries
- **Scope**: `dev`, `staging`, `prod` namespaces
- **Action**: Enforce (blocks pod creation)
- **Allowed Registries**:
  - `*.dkr.ecr.*.amazonaws.com` (Private ECR)
  - `public.ecr.aws` (Public ECR)
- **Rationale**: Prevents running untrusted images from public registries like Docker Hub

#### 4. **Verify Image Signatures** (High Severity)
- **Purpose**: Ensures all images are cryptographically signed with Cosign
- **Scope**: `dev`, `staging`, `prod` namespaces
- **Action**: Enforce (blocks pod creation)
- **Rationale**: Validates image integrity and authenticity, preventing supply chain attacks
- **Requirement**: Images must be signed with the Cosign private key matching the configured public key

### Pod Security Standards
All application namespaces enforce the `restricted` Pod Security Standard, which:
- Disables privilege escalation
- Requires running as non-root
- Drops all capabilities
- Enforces read-only root filesystem

### Network Policies
- **Default Deny**: All ingress traffic blocked by default
- **Same Namespace**: Pods can communicate within their namespace
- **kube-system/argocd**: Exempted for operational requirements

### Resource Quotas

| Namespace | CPU Requests | Memory Requests | CPU Limits | Memory Limits |
|-----------|--------------|-----------------|------------|---------------|
| dev       | 4 cores      | 8 GiB           | 8 cores    | 16 GiB        |
| staging   | 8 cores      | 16 GiB          | 16 cores   | 32 GiB        |
| prod      | 16 cores     | 32 GiB          | 32 cores   | 64 GiB        |

## 🔧 Customization

### Modify Variables

Edit `group_vars/all.yml` to customize:
- Helm chart versions
- Resource quotas
- Namespace configurations
- AWS region and cluster name

### Update Addon Versions

```yaml
# In group_vars/all.yml
argocd:
  version: "5.51.6"  # Change to desired version

metrics_server:
  version: "3.12.0"  # Change to desired version
```

## ✅ Post-Installation

### Access Argo CD

1. Get the admin password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

2. Port-forward to access UI:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

3. Open: `https://localhost:8080`
   - Username: `admin`
   - Password: (from step 1)

### Verify Installations

```bash
# Check all pods
kubectl get pods --all-namespaces

# Check Argo CD
kubectl get pods -n argocd

# Check addons
kubectl get pods -n kube-system

# Verify metrics server
kubectl top nodes

# Check network policies
kubectl get networkpolicies --all-namespaces

# Check resource quotas
kubectl get resourcequota --all-namespaces

# Verify Kyverno
kubectl get pods -n kyverno
kubectl get clusterpolicy
kubectl describe clusterpolicy disallow-latest-tag
```

### Test Kyverno Policies

```bash
# This should FAIL (latest tag blocked)
kubectl run test-latest --image=nginx:latest -n dev

# This should FAIL (no resource limits)
kubectl run test-no-limits --image=nginx:1.25 -n dev

# This should FAIL (non-ECR registry)
kubectl run test-docker-hub --image=docker.io/nginx:1.25 -n dev \
  --requests=cpu=100m,memory=128Mi --limits=cpu=200m,memory=256Mi

# This should SUCCEED
kubectl run test-success \
  --image=<your-ecr-url>/nginx:1.25 -n dev \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=200m,memory=256Mi
```

## 🔄 Integration with Azure Pipelines

Add this stage to your Azure Pipeline after Terraform:

```yaml
- stage: ConfigureEKS
  displayName: 'Configure EKS with Ansible'
  dependsOn: TerraformApply
  jobs:
    - job: RunAnsible
      displayName: 'Run Ansible Playbooks'
      steps:
        - task: Bash@3
          displayName: 'Install Ansible Collections'
          inputs:
            targetType: 'inline'
            script: |
              ansible-galaxy collection install kubernetes.core
              ansible-galaxy collection install community.general
              
        - task: Bash@3
          displayName: 'Update kubeconfig'
          inputs:
            targetType: 'inline'
            script: |
              aws eks update-kubeconfig \
                --name $(CLUSTER_NAME) \
                --region $(AWS_REGION)
                
        - task: Bash@3
          displayName: 'Run Ansible Playbook'
          inputs:
            targetType: 'inline'
            script: |
              cd infrastructure-repo/ansible
              ansible-playbook playbooks/configure-eks.yml
```

## 📝 Troubleshooting

### Common Issues

**Issue**: `kubernetes.core` collection not found
```bash
ansible-galaxy collection install kubernetes.core
```

**Issue**: Cannot connect to EKS cluster
```bash
# Update kubeconfig
aws eks update-kubeconfig --name <cluster-name> --region <region>

# Verify connection
kubectl cluster-info
```

**Issue**: IRSA role not found for AWS LB Controller
- Ensure Terraform created the IAM roles
- Export the role ARN: `export LB_CONTROLLER_ROLE_ARN="arn:..."`

**Issue**: Pods stuck in Pending
- Check resource quotas: `kubectl describe resourcequota -n <namespace>`
- Check node capacity: `kubectl top nodes`

## 📚 Additional Resources

- [Ansible Kubernetes Collection Docs](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
