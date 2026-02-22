# Self-Hosted Agent Setup Guide

This guide explains how to set up an Azure DevOps self-hosted agent to bypass the parallelism limitation.

## Why Self-Hosted Agent?

Microsoft-hosted agents require:
- **Public projects**: Free parallelism grant (2-3 days wait)
- **Private projects**: Purchased parallelism (~$40/month)

Self-hosted agents are:
- ✅ **Free** for unlimited pipelines
- ✅ **Immediate** setup (10 minutes)
- ✅ **Full control** over environment
- ✅ **Faster** (no queue, use your hardware)

---

## Prerequisites

- Linux machine (your local PC, VM, or cloud instance)
- Azure DevOps Personal Access Token (PAT)
- Sudo access

---

## Quick Setup (Automated)

### 1. Create Personal Access Token

1. Go to Azure DevOps
2. Click your profile icon → **Personal Access Tokens**
3. Click **+ New Token**
4. Configure:
   - **Name**: `Agent Pool Token`
   - **Organization**: Select your org
   - **Expiration**: 90 days (or custom)
   - **Scopes**: 
     - ✅ **Agent Pools (read, manage)**
     - ✅ **Deployment Groups (read, manage)**
5. Click **Create**
6. **Copy the token** (you won't see it again!)

### 2. Run Setup Script

```bash
cd infrastructure-repo
./scripts/setup-azdo-agent.sh
```

The script will ask for:
- Azure DevOps Organization URL (e.g., `https://dev.azure.com/yourorg`)
- Personal Access Token (paste the token from step 1)
- Agent Pool Name (press Enter for 'Default')
- Agent Name (press Enter for auto-generated)

### 3. Verify Agent is Online

1. Go to Azure DevOps
2. Click **Organization Settings** (bottom left)
3. Click **Agent pools** under Pipelines
4. Click **Default** pool
5. Click **Agents** tab
6. Your agent should show as **Online** 🟢

### 4. Run Your Pipeline

Your pipeline is already configured to use the `Default` pool. Just run it!

---

## Manual Setup (Alternative)

If you prefer manual setup:

### 1. Download Agent

```bash
# Create directory
mkdir -p ~/azpipelines-agent
cd ~/azpipelines-agent

# Download latest agent
curl -LsS https://vstsagentpackage.azureedge.net/agent/3.236.1/vsts-agent-linux-x64-3.236.1.tar.gz -o agent.tar.gz

# Extract
tar xzf agent.tar.gz
rm agent.tar.gz
```

### 2. Install Dependencies

```bash
sudo ./bin/installdependencies.sh
```

### 3. Configure Agent

```bash
./config.sh
```

Enter when prompted:
- **Server URL**: `https://dev.azure.com/YOUR_ORG`
- **Authentication type**: `PAT`
- **Personal access token**: Paste your token
- **Agent pool**: `Default` (press Enter)
- **Agent name**: Press Enter for default
- **Work folder**: Press Enter for default
- **Run as service**: `Y` (recommended)

### 4. Start Agent

If installed as service:
```bash
sudo ./svc.sh install
sudo ./svc.sh start
```

If running interactively:
```bash
./run.sh
```

---

## Agent Requirements

Your agent machine needs:

### Essential Tools
- ✅ `git` - Version control
- ✅ `curl`, `wget` - File downloads
- ✅ `tar`, `unzip` - Archive extraction

### Infrastructure Tools (Auto-installed by pipeline)
- Terraform (pipeline installs)
- Ansible (pipeline installs)
- kubectl (pipeline installs)
- AWS CLI (pipeline installs)

### Docker (Optional, for container jobs)
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add agent user to docker group
sudo usermod -aG docker $(whoami)
```

---

## Pipeline Configuration

The pipelines are already configured for self-hosted agents:

```yaml
pool:
  name: 'Default'  # Uses self-hosted agent pool
```

To switch back to Microsoft-hosted (after getting parallelism):
```yaml
pool:
  vmImage: 'ubuntu-latest'
```

---

## Multiple Agents

To run multiple pipelines in parallel, set up multiple agents:

```bash
# Agent 1
cd ~/azpipelines-agent-1
./config.sh --agent agent-1

# Agent 2  
cd ~/azpipelines-agent-2
./config.sh --agent agent-2
```

---

## Cloud VM Agent (AWS EC2 Example)

### 1. Launch EC2 Instance

```bash
# t3.medium recommended (2 vCPU, 4GB RAM)
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.medium \
  --key-name your-key \
  --security-group-ids sg-xxx \
  --subnet-id subnet-xxx \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=azdo-agent}]'
```

### 2. Connect and Setup

```bash
# SSH to instance
ssh -i your-key.pem ubuntu@<instance-ip>

# Install agent
curl -LO https://raw.githubusercontent.com/YOUR_REPO/main/scripts/setup-azdo-agent.sh
chmod +x setup-azdo-agent.sh
./setup-azdo-agent.sh
```

### Cost Estimate
- **t3.medium**: ~$30/month (always on)
- **t3.medium spot**: ~$10/month (can be interrupted)

---

## Troubleshooting

### Agent Offline

**Check agent status**:
```bash
cd ~/azpipelines-agent
sudo ./svc.sh status
```

**Restart agent**:
```bash
sudo ./svc.sh stop
sudo ./svc.sh start
```

### Pipeline Not Using Agent

**Verify pool name matches**:
- Pipeline: `pool: name: 'Default'`
- Agent pool: Must be named `Default`

**Check agent is online**:
- Go to Organization Settings → Agent pools → Default
- Agent should show green 🟢

### Permission Errors

**AWS credentials**:
- Agent needs AWS credentials configured
- Option 1: IAM role (for EC2)
- Option 2: Environment variables
- Option 3: `~/.aws/credentials` file

**Git authentication**:
- Pipeline uses Azure Repos built-in auth
- For external repos, configure Git credentials

---

## Security Best Practices

### 1. Isolate Agent

- ✅ Use dedicated VM/container for agent
- ✅ Don't run on your personal workstation
- ✅ Use separate agent per environment (dev/prod)

### 2. Limit Permissions

- ✅ Use least-privilege IAM roles
- ✅ Restrict agent pool access
- ✅ Use scoped PATs (not full access)

### 3. Rotate Credentials

- ✅ Rotate PAT every 90 days
- ✅ Rotate AWS credentials regularly
- ✅ Monitor agent activity logs

---

## Agent Maintenance

### Update Agent

```bash
cd ~/azpipelines-agent
sudo ./svc.sh stop
./config.sh remove
# Download new version
curl -LsS <NEW_AGENT_URL> -o agent.tar.gz
tar xzf agent.tar.gz
./config.sh
sudo ./svc.sh install
sudo ./svc.sh start
```

### Uninstall Agent

```bash
cd ~/azpipelines-agent
sudo ./svc.sh stop
sudo ./svc.sh uninstall
./config.sh remove
cd ~
rm -rf ~/azpipelines-agent
```

---

## Comparison: Self-Hosted vs Microsoft-Hosted

| Feature | Self-Hosted | Microsoft-Hosted |
|---------|-------------|------------------|
| **Cost** | Free | Free (public) or $40/mo |
| **Setup Time** | 10 minutes | Instant (after grant) |
| **Wait Time** | None | 2-3 days (grant approval) |
| **Performance** | Your hardware | Shared, slower |
| **Cached Dependencies** | Yes, persistent | No, fresh each time |
| **Custom Software** | Full control | Limited |
| **Maintenance** | Your responsibility | Microsoft maintains |
| **Security** | Your control | Microsoft managed |
| **Parallel Jobs** | Unlimited (with agents) | Limited by grant/purchase |

---

## Recommended Setup

### For Learning/Development
- ✅ Self-hosted on local machine or cheap cloud VM
- Free and immediate

### For Production
- ✅ Self-hosted on dedicated EC2/VM
- Or Microsoft-hosted with purchased parallelism

---

## Next Steps

After setting up the agent:

1. ✅ Verify agent is online in Azure DevOps
2. ✅ Pipeline is configured to use `Default` pool
3. ✅ Run the infrastructure pipeline
4. ✅ Monitor first run to ensure all tools install correctly

---

**Estimated Setup Time**: 10-15 minutes  
**Cost**: Free (if using existing machine)  
**Maintenance**: Minimal (update quarterly)
