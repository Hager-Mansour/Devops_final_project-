# Agent Dependency Pre-Installation Guide

## Overview

To speed up your pipeline, pre-install all dependencies on your self-hosted agent. This eliminates the need to download tools on every pipeline run.

## Quick Setup

Run this single command on your agent machine:

```bash
cd /path/to/infrastructure-repo
./scripts/bootstrap-agent.sh
```

This script installs everything automatically and takes ~5-10 minutes.

---

## What Gets Installed

### 1. **System Packages**
- `curl`, `wget` - File downloads
- `git` - Version control
- `unzip`, `tar` - Archive extraction
- `jq` - JSON processing
- `python3`, `python3-pip` - Python runtime

### 2. **Infrastructure Tools**
| Tool | Version | Purpose |
|------|---------|---------|
| **Terraform** | 1.6.0 | Infrastructure provisioning |
| **AWS CLI** | Latest | AWS resource management |
| **kubectl** | Latest stable | Kubernetes management |
| **Ansible** | 2.14.x | Configuration management |

### 3. **Ansible Collections**
- `kubernetes.core` - Kubernetes modules
- `community.general` - General utilities

### 4. **Python Packages**
- `PyYAML` - YAML parsing
- `jinja2` - Templates
- `openshift` - Kubernetes Python client
- `kubernetes` - Kubernetes Python SDK

### 5. **Security Scanning Tools**
| Tool | Purpose |
|------|---------|
| **tfsec** | Terraform security scanner |
| **Checkov** | Policy-as-code validator |
| **Cosign** (optional) | Image signing/verification |

---

## Manual Installation (Alternative)

If you prefer to install tools manually:

### Terraform
```bash
TERRAFORM_VERSION="1.6.0"
wget "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
unzip "terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
sudo mv terraform /usr/local/bin/
```

### AWS CLI
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
```

### kubectl
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Ansible
```bash
pip3 install --user ansible==2.14.*
export PATH="$HOME/.local/bin:$PATH"
ansible-galaxy collection install kubernetes.core community.general
```

### Security Tools
```bash
# tfsec
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# Checkov
pip3 install --user checkov

# Cosign (optional)
COSIGN_VERSION="v2.2.0"
wget "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64"
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign
```

---

## Verification

After installation, verify all tools are available:

```bash
terraform version
aws --version
kubectl version --client
ansible --version
tfsec --version
checkov --version
cosign version
```

---

## Pipeline Changes

The pipeline has been optimized to use pre-installed tools:

### Before (Downloads every time):
```yaml
- template: pipelines/templates/terraform-install.yml  # Downloads Terraform
- template: pipelines/templates/ansible-install.yml     # Downloads Ansible
- script: |
    curl -LO kubectl...  # Downloads kubectl
    curl awscli...       # Downloads AWS CLI
```

### After (Just verifies):
```yaml
- template: pipelines/templates/verify-tools.yml  # Quick check only
```

**Speed Improvement**: ~5-10 minutes saved per run!

---

## Updating Tools

To update tools in the future, re-run the bootstrap script:

```bash
./scripts/bootstrap-agent.sh
```

Or update individually:

### Update Terraform
```bash
# Check current version
terraform version

# Download new version
TERRAFORM_VERSION="1.7.0"
wget "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
unzip "terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
sudo mv terraform /usr/local/bin/
```

### Update AWS CLI
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --update
```

### Update kubectl
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Update Ansible
```bash
pip3 install --user --upgrade ansible
ansible-galaxy collection install --force kubernetes.core community.general
```

---

## Troubleshooting

### "Command not found" errors in pipeline

**Cause**: Tool not installed or not in PATH

**Solution**:
1. SSH to agent machine
2. Run: `./scripts/bootstrap-agent.sh`
3. Restart pipeline

### PATH issues

**Cause**: Tools installed in `~/.local/bin` not in PATH

**Solution**:
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Permission errors

**Cause**: Tools require sudo but agent doesn't have permissions

**Solution**:
- Tools are installed globally (`/usr/local/bin`)
- Agent user needs sudo access (passwordless recommended)
- Add to `/etc/sudoers`: `agent-user ALL=(ALL) NOPASSWD: ALL`

---

## Disk Space Requirements

Approximate disk space needed:

| Tool | Size |
|------|------|
| Terraform | ~50 MB |
| AWS CLI | ~200 MB |
| kubectl | ~50 MB |
| Ansible + deps | ~300 MB |
| Security tools | ~100 MB |
| **Total** | **~700 MB** |

Plus workspace for Terraform state, build artifacts, etc. (~2 GB recommended).

---

## Summary

**Before Optimization**:
- Pipeline downloads tools every run
- ~5-10 minutes wasted per run
- Network dependent

**After Optimization**:
- ✅ Tools pre-installed on agent
- ✅ ~2 seconds verification only
- ✅ Faster, more reliable pipelines
- ✅ No repeated downloads

**Setup Time**: 10 minutes (one-time)  
**Time Saved Per Run**: 5-10 minutes  
**Break-even**: After 1-2 pipeline runs!

---

## Next Steps

1. Run `./scripts/bootstrap-agent.sh` on your agent
2. Verify tools are installed
3. Run your pipeline - it will be much faster!

The pipeline will now use the `verify-tools.yml` template which just checks that tools exist, instead of downloading them every time.
