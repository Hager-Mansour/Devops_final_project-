#!/bin/bash
# Bootstrap Script for Azure DevOps Self-Hosted Agent
# Installs ALL required dependencies for the infrastructure pipeline
# Run this ONCE on your agent machine after setting up the agent

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Agent Bootstrap - Installing Dependencies${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Track installation status
INSTALLED=()
FAILED=()

# Helper function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Helper function to install and track
install_tool() {
    local tool_name="$1"
    local check_cmd="$2"
    local install_func="$3"
    
    echo -e "${YELLOW}Checking ${tool_name}...${NC}"
    
    if command_exists "$check_cmd"; then
        local version=$(eval "$check_cmd --version 2>&1 | head -n1" || echo "installed")
        echo -e "${GREEN}✓ ${tool_name} already installed: ${version}${NC}"
        INSTALLED+=("$tool_name (existing)")
    else
        echo -e "${YELLOW}Installing ${tool_name}...${NC}"
        if $install_func; then
            local version=$(eval "$check_cmd --version 2>&1 | head -n1" || echo "installed")
            echo -e "${GREEN}✓ ${tool_name} installed: ${version}${NC}"
            INSTALLED+=("$tool_name")
        else
            echo -e "${RED}✗ Failed to install ${tool_name}${NC}"
            FAILED+=("$tool_name")
        fi
    fi
    echo ""
}

# ============================================
# 1. System Packages
# ============================================
echo -e "${BLUE}[1/8] Installing System Packages${NC}"
echo ""

install_system_packages() {
    sudo apt-get update -qq
    sudo apt-get install -y \
        curl \
        wget \
        git \
        unzip \
        tar \
        jq \
        python3 \
        python3-pip \
        ca-certificates \
        gnupg \
        lsb-release
}

if ! dpkg -l | grep -q curl; then
    echo -e "${YELLOW}Installing system packages...${NC}"
    install_system_packages
    echo -e "${GREEN}✓ System packages installed${NC}"
else
    echo -e "${GREEN}✓ System packages already installed${NC}"
fi
echo ""

# ============================================
# 2. Terraform
# ============================================
echo -e "${BLUE}[2/8] Installing Terraform${NC}"
echo ""

install_terraform() {
    TERRAFORM_VERSION="1.6.0"
    wget -q "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
    unzip -q "terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
    sudo mv terraform /usr/local/bin/
    rm "terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
    sudo chmod +x /usr/local/bin/terraform
}

install_tool "Terraform" "terraform" "install_terraform"

# ============================================
# 3. AWS CLI
# ============================================
echo -e "${BLUE}[3/8] Installing AWS CLI${NC}"
echo ""

install_aws_cli() {
    curl -sS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install --update 2>/dev/null || sudo ./aws/install
    rm -rf aws awscliv2.zip
}

install_tool "AWS CLI" "aws" "install_aws_cli"

# ============================================
# 4. kubectl
# ============================================
echo -e "${BLUE}[4/8] Installing kubectl${NC}"
echo ""

install_kubectl() {
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
}

install_tool "kubectl" "kubectl" "install_kubectl"

# ============================================
# 5. Ansible
# ============================================
echo -e "${BLUE}[5/8] Installing Ansible${NC}"
echo ""

install_ansible() {
    pip3 install --user ansible==2.14.* --break-system-packages --quiet
    # Add to PATH if not already
    if ! grep -q ".local/bin" ~/.bashrc; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/.local/bin:$PATH"
    fi
}

install_tool "Ansible" "ansible" "install_ansible"

# ============================================
# 6. Ansible Collections
# ============================================
echo -e "${BLUE}[6/8] Installing Ansible Collections${NC}"
echo ""

if command_exists ansible-galaxy; then
    echo -e "${YELLOW}Installing kubernetes.core collection...${NC}"
    ansible-galaxy collection install kubernetes.core --force 2>/dev/null
    echo -e "${GREEN}✓ kubernetes.core installed${NC}"
    
    echo -e "${YELLOW}Installing community.general collection...${NC}"
    ansible-galaxy collection install community.general --force 2>/dev/null
    echo -e "${GREEN}✓ community.general installed${NC}"
    INSTALLED+=("Ansible Collections")
else
    echo -e "${RED}✗ Ansible not found, skipping collections${NC}"
    FAILED+=("Ansible Collections")
fi
echo ""

# ============================================
# 7. Python Packages
# ============================================
echo -e "${BLUE}[7/8] Installing Python Packages${NC}"
echo ""

echo -e "${YELLOW}Installing Python packages...${NC}"
pip3 install --user --quiet --break-system-packages \
    PyYAML \
    jinja2 \
    openshift \
    kubernetes

echo -e "${GREEN}✓ Python packages installed${NC}"
INSTALLED+=("Python packages")
echo ""

# ============================================
# 8. Security Scanning Tools
# ============================================
echo -e "${BLUE}[8/8] Installing Security Scanning Tools${NC}"
echo ""

# tfsec
install_tfsec() {
    curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
}

install_tool "tfsec" "tfsec" "install_tfsec"

# Checkov
install_checkov() {
    pip3 install --user checkov --break-system-packages --quiet
}

install_tool "Checkov" "checkov" "install_checkov"

# ============================================
# 9. Optional: Cosign (for image signing)
# ============================================
echo -e "${BLUE}[Optional] Installing Cosign${NC}"
echo ""

install_cosign() {
    COSIGN_VERSION="v2.2.0"
    wget -q "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64"
    sudo mv cosign-linux-amd64 /usr/local/bin/cosign
    sudo chmod +x /usr/local/bin/cosign
}

install_tool "Cosign" "cosign" "install_cosign"

# ============================================
# Summary
# ============================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${GREEN}Successfully Installed (${#INSTALLED[@]}):${NC}"
for tool in "${INSTALLED[@]}"; do
    echo -e "  ${GREEN}✓${NC} $tool"
done

if [ ${#FAILED[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}Failed (${#FAILED[@]}):${NC}"
    for tool in "${FAILED[@]}"; do
        echo -e "  ${RED}✗${NC} $tool"
    done
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Verification${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verify all tools
echo "Version Check:"
echo "  Terraform:  $(terraform version | head -n1)"
echo "  AWS CLI:    $(aws --version 2>&1 | head -n1)"
echo "  kubectl:    $(kubectl version --client --short 2>/dev/null || echo "$(kubectl version --client 2>&1 | head -n1)")"
echo "  Ansible:    $(ansible --version | head -n1)"
echo "  tfsec:      $(tfsec --version 2>&1 | head -n1 || echo "not installed")"
echo "  Checkov:    $(checkov --version 2>&1 || echo "not installed")"
echo "  Cosign:     $(cosign version 2>&1 | head -n1 || echo "not installed")"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Bootstrap Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Your agent is now ready to run infrastructure pipelines."
echo ""
echo "Next steps:"
echo "1. Restart your shell or run: source ~/.bashrc"
echo "2. Verify agent is running: cd ~/azpipelines-agent && ./svc.sh status"
echo "3. Run your Azure DevOps pipeline"
echo ""
echo "To update tools in the future, re-run this script."
echo ""
