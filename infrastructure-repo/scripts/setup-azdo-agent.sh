#!/bin/bash
# Azure DevOps Self-Hosted Agent Setup Script
# This script installs and configures a self-hosted agent for Azure Pipelines

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Azure DevOps Self-Hosted Agent Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}Error: This script is for Linux only${NC}"
    exit 1
fi

# Check for required tools
command -v curl >/dev/null 2>&1 || { echo -e "${RED}Error: curl is required${NC}"; exit 1; }
command -v tar >/dev/null 2>&1 || { echo -e "${RED}Error: tar is required${NC}"; exit 1; }

echo -e "${GREEN}✓ Prerequisites met${NC}"
echo ""

# Gather information
echo -e "${YELLOW}Please provide the following information:${NC}"
echo ""

read -p "Azure DevOps Organization URL (e.g., https://dev.azure.com/yourorg): " ORG_URL
read -p "Personal Access Token (PAT): " PAT
read -p "Agent Pool Name (press Enter for 'Default'): " POOL_NAME
POOL_NAME=${POOL_NAME:-Default}
read -p "Agent Name (press Enter for '$(hostname)-agent'): " AGENT_NAME
AGENT_NAME=${AGENT_NAME:-$(hostname)-agent}

echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Organization: $ORG_URL"
echo "  Pool: $POOL_NAME"
echo "  Agent Name: $AGENT_NAME"
echo ""

read -p "Continue with this configuration? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Setup cancelled."
    exit 0
fi

# Create agent directory
AGENT_DIR="$HOME/azpipelines-agent"
echo ""
echo -e "${YELLOW}Creating agent directory: $AGENT_DIR${NC}"
mkdir -p "$AGENT_DIR"
cd "$AGENT_DIR"

# Download the latest agent
echo -e "${YELLOW}Downloading latest agent...${NC}"
AGENT_VERSION="3.236.1"  # Update this to latest version if needed
AGENT_URL="https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz"

curl -LsS "$AGENT_URL" -o agent.tar.gz
echo -e "${GREEN}✓ Agent downloaded${NC}"

# Extract agent
echo -e "${YELLOW}Extracting agent...${NC}"
tar xzf agent.tar.gz
rm agent.tar.gz
echo -e "${GREEN}✓ Agent extracted${NC}"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo ./bin/installdependencies.sh
echo -e "${GREEN}✓ Dependencies installed${NC}"

# Configure agent
echo ""
echo -e "${YELLOW}Configuring agent...${NC}"
./config.sh \
    --unattended \
    --url "$ORG_URL" \
    --auth pat \
    --token "$PAT" \
    --pool "$POOL_NAME" \
    --agent "$AGENT_NAME" \
    --replace \
    --acceptTeeEula

echo -e "${GREEN}✓ Agent configured${NC}"

# Install as service (optional)
echo ""
read -p "Install agent as a system service? (y/n): " INSTALL_SERVICE
if [[ "$INSTALL_SERVICE" == "y" || "$INSTALL_SERVICE" == "Y" ]]; then
    sudo ./svc.sh install
    sudo ./svc.sh start
    echo -e "${GREEN}✓ Agent installed and started as service${NC}"
    echo ""
    echo -e "${GREEN}Agent is running in the background${NC}"
else
    echo ""
    echo -e "${YELLOW}To start the agent manually, run:${NC}"
    echo "  cd $AGENT_DIR"
    echo "  ./run.sh"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Agent Details:"
echo "  Name: $AGENT_NAME"
echo "  Pool: $POOL_NAME"
echo "  Directory: $AGENT_DIR"
echo ""
echo "Next Steps:"
echo "1. Go to Azure DevOps → Organization Settings → Agent Pools"
echo "2. Select '$POOL_NAME' pool"
echo "3. Verify your agent '$AGENT_NAME' is online"
echo "4. Update pipeline to use this pool"
echo ""
echo "To uninstall:"
echo "  cd $AGENT_DIR"
echo "  ./config.sh remove"
echo ""
