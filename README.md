# 🚀 Webserver Infrastructure

[![Build and Push](https://github.com/VerilyPete/webserver/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/VerilyPete/webserver/actions/workflows/build-and-push.yml)
[![Deploy](https://github.com/VerilyPete/webserver/actions/workflows/deploy-or-update-via-tailscale.yml/badge.svg)](https://github.com/VerilyPete/webserver/actions/workflows/deploy-or-update-via-tailscale.yml)

A **containerized web server infrastructure** that provides automated deployment of web applications to Oracle Cloud Infrastructure (OCI) using Tailscale VPN for secure connectivity and GitHub Actions for CI/CD.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment Process](#deployment-process)
- [Container Architecture](#container-architecture)
- [Monitoring & Maintenance](#monitoring--maintenance)
- [Troubleshooting](#troubleshooting)
- [Security](#security)
- [Development](#development)
- [API Reference](#api-reference)
- [Examples](#examples)
- [FAQ](#faq)
- [Changelog](#changelog)
- [License](#license)

## 🎯 Overview

This infrastructure provides a complete solution for deploying web applications with the following key features:

- ✅ **Zero-downtime deployments** via GitHub Actions
- ✅ **Secure VPN connectivity** via Tailscale mesh network
- ✅ **Containerized architecture** using Podman
- ✅ **Multi-environment support** (staging/production)
- ✅ **Automated CI/CD pipeline** with build and deployment workflows
- ✅ **Formspree integration** for contact forms
- ✅ **Cloudflare Tunnel support** for public access
- ✅ **Cost-effective** ARM-based OCI instances

### What It Does

The infrastructure automatically:
1. Creates or updates OCI compute instances
2. Bootstraps instances with cloud-init configuration
3. Establishes secure Tailscale VPN connectivity
4. Deploys containerized web applications
5. Configures reverse proxy and optional tunnels
6. Provides monitoring and maintenance tools

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   GitHub Repo   │    │   GitHub Actions │    │   OCI Instance  │
│                 │    │                  │    │                 │
│ ┌─────────────┐ │    │ ┌──────────────┐ │    │ ┌─────────────┐ │
│ │ Web Content │ │    │ │ Build Image  │ │    │ │ Cloud-init  │ │
│ │             │ │    │ │              │ │    │ │ Bootstrap   │ │
│ └─────────────┘ │    │ └──────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │Container Registry│    │   Tailscale     │
                       │      (GHCR)      │    │   VPN Network   │
                       └──────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │   Podman Pod    │
                                               │                 │
                                               │ ┌─────────────┐ │
                                               │ │   Nginx     │ │
                                               │ │  (Web App)  │ │
                                               │ └─────────────┘ │
                                               │ ┌─────────────┐ │
                                               │ │ Cloudflared │ │
                                               │ │  (Tunnel)   │ │
                                               │ └─────────────┘ │
                                               └─────────────────┘
```

### Components

- **OCI Compute Instance**: VM.Standard.A1.Flex (ARM-based, cost-effective)
- **Tailscale VPN**: Secure mesh network for remote access
- **Podman Containers**: Lightweight container runtime
- **Nginx**: Reverse proxy and web server
- **Cloudflare Tunnel**: Optional public access tunnel
- **GitHub Actions**: CI/CD automation

## 📋 Prerequisites

Before deploying this infrastructure, ensure you have:

### Required Accounts
- ✅ **Oracle Cloud Infrastructure** account with API access
- ✅ **GitHub** account with repository access
- ✅ **Tailscale** account with auth key
- ✅ **Formspree** account (for contact forms)

### Optional Accounts
- 🔧 **Cloudflare** account (for tunnel access)

### Technical Requirements
- OCI compartment with private subnet configured
- Custom OCI image with Podman pre-installed
- SSH key pair for secure access
- GitHub repository with secrets management

## 🚀 Quick Start

### For New Deployments

1. **Configure GitHub Secrets** (see [Configuration](#configuration) section)
2. **Navigate to GitHub Actions** in your repository
3. **Run the "Deploy or Update via Tailscale" workflow**
4. **Select parameters**:
   - **Deployment type**: `fresh_deploy`
   - **Target hostname**: `webserver-staging` or `webserver-prod`
5. **Monitor the deployment** in the Actions tab

### For Updates

1. **Navigate to GitHub Actions** in your repository
2. **Run the "Deploy or Update via Tailscale" workflow**
3. **Select parameters**:
   - **Deployment type**: `update`
   - **Target hostname**: `webserver-staging` or `webserver-prod`
4. **Wait for completion** (typically ~40 seconds on a single OCPU Ampere A1 instance)

### Access Your Deployment

Once deployed, access your web server via:
- **Tailscale**: `http://[hostname]:8081`
- **Cloudflare Tunnel**: `https://[your-domain]` (if configured)

## ⚙️ Configuration

### Required GitHub Secrets

#### OCI Credentials
```bash
OCI_CLI_USER          # OCI user OCID
OCI_CLI_TENANCY       # OCI tenancy OCID
OCI_CLI_FINGERPRINT   # API key fingerprint
OCI_CLI_KEY_CONTENT   # Private API key content
OCI_CLI_REGION        # OCI region (e.g., us-ashburn-1)
```

#### OCI Resources
```bash
OCI_COMPARTMENT_ID    # Compartment OCID
OCI_AVAILABILITY_DOMAIN  # Availability domain
OCI_CUSTOM_IMAGE      # Custom image OCID with Podman
OCI_PRIVATE_SUBNET    # Private subnet OCID
```

#### SSH Keys
```bash
SSH_PUBLIC_KEY        # Public SSH key for instance access
SSH_PRIVATE_KEY       # Private SSH key for GitHub Actions
```

#### Tailscale
```bash
TAILSCALE_AUTH_KEY    # Tailscale auth key for instance
PRIVATE_TAILSCALE_KEY # Tailscale auth key for GitHub Actions
```

#### Cloudflare (Optional)
```bash
CLOUDFLARE_PROD_TUNNEL_TOKEN   # Production tunnel token
CLOUDFLARE_STAGING_TUNNEL_TOKEN # Staging tunnel token
```

#### Application
```bash
FORMSPREE_ENDPOINT    # Formspree endpoint for contact forms
GHCR_TOKEN            # GitHub Container Registry token
```

### Environment Variables

The deployment creates a `.env` file on the instance with:

```bash
HOSTNAME=webserver-staging
TAILSCALE_AUTH_KEY=your-tailscale-key
CLOUDFLARE_TUNNEL_TOKEN=your-tunnel-token
FORMSPREE_ENDPOINT=your-formspree-endpoint
APP_PORT=8081
APP_ENV=production
```

## 🔄 Deployment Process

### Step-by-Step Breakdown

1. **Instance Management**
   - **Fresh Deploy**: Terminates existing instance, creates new one
   - **Update**: Uses existing instance

2. **Cloud-init Bootstrap**
   - Installs and configures Podman
   - Sets up system optimizations
   - Configures Tailscale service
   - Establishes initial VPN connectivity

3. **Tailscale Connectivity**
   - Waits for Tailscale to establish connection
   - Verifies SSH access via VPN
   - Sets up user systemd services

4. **Infrastructure Setup**
   - Clones/updates repository
   - Creates environment configuration
   - Sets up systemd service files
   - Configures container orchestration

5. **Container Deployment**
   - Creates Podman pod
   - Pulls latest container images
   - Starts web application containers
   - Configures optional Cloudflare tunnel

6. **Verification**
   - Checks service status
   - Validates container health
   - Confirms web server accessibility

### Deployment Timeline

- **Fresh Deploy**: ~5 minutes
- **Update**: ~35 seconds
- **Build Time**: ~45 seconds (parallel)

## 🐳 Container Architecture

### Pod Structure

```
webserver-pod (Podman Pod)
├── web-pod (pause container)
├── web (nginx container)
│   ├── Port: 8081
│   ├── Volume: nginx.conf
│   └── Image: ghcr.io/verilypete/webserver:latest
└── cloudflared (optional)
    ├── Environment: TUNNEL_TOKEN
    └── Image: docker.io/cloudflare/cloudflared:latest

tailscale (separate container)
├── Network: host
├── Privileged: true
└── Image: docker.io/tailscale/tailscale:latest
```

### Container Details

#### Web Container
- **Base Image**: `nginx:alpine`
- **Port**: 8081
- **Features**:
  - Static file serving
  - Formspree proxy integration
  - Caching headers
  - Error page handling
  - Health checks

#### Cloudflared Container (Optional)
- **Purpose**: Public access tunnel
- **Configuration**: Environment-based tunnel token
- **Features**: Automatic reconnection, load balancing

#### Tailscale Container
- **Purpose**: VPN connectivity
- **Network**: Host networking
- **Features**: Mesh network, secure access

### Volume Mounts

- **nginx.conf**: Dynamic configuration with Formspree endpoint
- **tailscale-data**: Persistent VPN state
- **Website Content**: Built into container image

## 📊 Monitoring & Maintenance

### Health Checks

```bash
# Check container status
ssh opc@[hostname] 'podman pod ps'
ssh opc@[hostname] 'podman ps'

# Check service status
ssh opc@[hostname] 'systemctl --user status webserver-pod.service'

# Check logs
ssh opc@[hostname] 'journalctl --user -u webserver-pod.service -f'
```

### Automated Maintenance

The infrastructure includes automated cleanup scripts:

- **Container Cleanup**: Daily removal of unused containers/images
- **Log Rotation**: Automatic log management
- **System Updates**: Periodic security updates

### Manual Maintenance

```bash
# Update containers
ssh opc@[hostname] 'cd ~/webserver && git pull && systemctl --user restart webserver-pod.service'

# View logs
ssh opc@[hostname] 'podman logs web'
ssh opc@[hostname] 'podman logs cloudflared'

# Restart services
ssh opc@[hostname] 'systemctl --user restart webserver-pod.service'
```

## 🔧 Troubleshooting

### Common Issues

#### Tailscale Connectivity Problems

**Symptoms**: SSH connection fails, containers can't start

**Solutions**:
```bash
# Check Tailscale status
ssh opc@[hostname] 'podman logs tailscale'

# Restart Tailscale service
ssh opc@[hostname] 'systemctl --user restart tailscale.service'

# Verify Tailscale admin console
# Check if device is authorized and connected
```

#### Container Startup Failures

**Symptoms**: Web server not accessible, service failed

**Solutions**:
```bash
# Check container logs
ssh opc@[hostname] 'podman logs web'

# Check service status
ssh opc@[hostname] 'systemctl --user status webserver-pod.service'

# Restart pod
ssh opc@[hostname] 'systemctl --user restart webserver-pod.service'
```

#### Cloud-init Errors

**Symptoms**: Instance creation fails, bootstrap incomplete

**Solutions**:
```bash
# Check cloud-init logs
ssh opc@[hostname] 'sudo cat /var/log/cloud-init-output.log'

# Verify metadata retrieval
ssh opc@[hostname] 'curl -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/metadata/TAILSCALE_AUTH_KEY'
```

#### GitHub Actions Failures

**Symptoms**: Workflow fails, deployment incomplete

**Solutions**:
1. Check GitHub Actions logs for specific error messages
2. Verify all required secrets are configured
3. Ensure OCI resources exist and are accessible
4. Check Tailscale auth key validity

### Debug Commands

```bash
# System information
ssh opc@[hostname] 'uname -a && cat /etc/os-release'

# Network connectivity
ssh opc@[hostname] 'ip addr show && ping -c 3 1.1.1.1'

# Container resources
ssh opc@[hostname] 'podman system df && podman pod ps'

# Service status
ssh opc@[hostname] 'systemctl --user list-units --failed'
```

## 🔒 Security

### Network Security

- **Private Subnet**: Instances deployed in private OCI subnet
- **No Public IP**: Instances have no direct internet access
- **VPN Access**: All access via Tailscale mesh network
- **Firewall Rules**: Minimal port exposure (8081 only)

### Container Security

- **Non-root Containers**: Containers run as non-privileged users
- **SELinux**: Context-aware security policies
- **Image Scanning**: Built from trusted base images
- **Secret Management**: Environment-based configuration

### Access Control

- **SSH Keys**: Key-based authentication only
- **Tailscale ACLs**: Network-level access control
- **GitHub Secrets**: Encrypted secret storage
- **OCI IAM**: Principle of least privilege

### Data Protection

- **No Persistent Storage**: Stateless container design
- **Encrypted Transit**: All communications encrypted
- **Secret Rotation**: Support for credential rotation
- **Audit Logging**: Comprehensive logging and monitoring

## 🛠️ Development

### Local Development

```bash
# Clone repository
git clone https://github.com/VerilyPete/webserver.git
cd webserver

# Build container locally
cd web
docker build -t webserver:local .

# Run locally
docker run -p 8081:8081 webserver:local
```

### Testing Changes

1. **Local Testing**: Test container builds locally
2. **Staging Deployment**: Deploy to staging environment first
3. **Production Deployment**: Deploy to production after validation

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📚 API Reference

### GitHub Actions Workflows

#### Build and Push Workflow
- **Trigger**: Push to main branch, manual dispatch
- **Purpose**: Build and push container images
- **Output**: Multi-platform images to GHCR

#### Deploy Workflow
- **Trigger**: Manual dispatch only
- **Parameters**:
  - `deploy_type`: `update` or `fresh_deploy`
  - `hostname`: `webserver-staging` or `webserver-prod`
- **Purpose**: Deploy or update infrastructure

### Container Images

#### Available Tags
- `latest`: Latest stable build
- `main-[commit]`: Branch-specific builds
- `[version]`: Versioned releases

#### Image Variants
- `linux/amd64`: x86_64 architecture
- `linux/arm64`: ARM64 architecture

### Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `HOSTNAME` | Instance hostname | Yes | - |
| `TAILSCALE_AUTH_KEY` | Tailscale authentication key | Yes | - |
| `CLOUDFLARE_TUNNEL_TOKEN` | Cloudflare tunnel token | No | - |
| `FORMSPREE_ENDPOINT` | Formspree endpoint URL | Yes | - |
| `APP_PORT` | Web server port | No | 8081 |
| `APP_ENV` | Environment name | No | production |

## 💡 Examples

### Basic Deployment

```yaml
# GitHub Actions workflow example
- name: Deploy to Staging
  uses: actions/github-script@v6
  with:
    script: |
      github.rest.actions.createWorkflowDispatch({
        owner: 'VerilyPete',
        repo: 'webserver',
        workflow_id: 'deploy-or-update-via-tailscale.yml',
        ref: 'main',
        inputs: {
          deploy_type: 'update',
          hostname: 'webserver-staging'
        }
      })
```

### Custom Configuration

```bash
# Custom nginx configuration
location /api {
    proxy_pass http://backend:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

### Integration with External Services

```bash
# Formspree integration
location /submit-form {
    proxy_pass https://formspree.io/f/your-form-id;
    proxy_set_header Host formspree.io;
    proxy_set_header X-Real-IP $remote_addr;
}
```

## ❓ FAQ

### General Questions

**Q: How much does this cost to run?**
A: OCI ARM instances are very cost-effective. A VM.Standard.A1.Flex with 1 OCPU and 6GB RAM is eligible for OCI's always free tier.

**Q: Can I use this for multiple websites?**
A: Yes! You can deploy multiple instances with different hostnames or use a single instance with multiple containers.

**Q: Is this production-ready?**
A: Yes, this infrastructure is designed for production use with proper security, monitoring, and backup capabilities.

### Technical Questions

**Q: How do I update the website content?**
A: Content is built into the container image. Update your content repository and trigger a new build/deployment.

**Q: Can I use a different cloud provider?**
A: The cloud-init and deployment scripts are OCI-specific, but the container architecture is portable.

**Q: How do I add SSL certificates?**
A: Use Cloudflare Tunnel for automatic SSL or configure certificates in the nginx configuration.

### Troubleshooting Questions

**Q: My deployment failed, what should I check?**
A: Check GitHub Actions logs, verify all secrets are configured, and ensure OCI resources exist.

**Q: I can't access my website, what's wrong?**
A: Verify Tailscale connectivity, check container status, and ensure the web server is running on port 8081.

**Q: How do I scale this infrastructure?**
A: Deploy multiple instances behind a load balancer or use OCI's auto-scaling features.

## 📝 Changelog

### [Unreleased]
- Initial release
- Basic containerized web server infrastructure
- Tailscale VPN integration
- GitHub Actions CI/CD pipeline
- Multi-environment support

### [v1.0.0] - 2024-01-01
- Initial stable release
- Complete documentation
- Production-ready deployment process


## 🤝 Support

- **Issues**: [GitHub Issues](https://github.com/VerilyPete/webserver/issues)
- **Discussions**: [GitHub Discussions](https://github.com/VerilyPete/webserver/discussions)
- **Documentation**: This README and inline code comments

## 🙏 Acknowledgments

- [Oracle Cloud Infrastructure](https://www.oracle.com/cloud/) for the cloud platform
- [Tailscale](https://tailscale.com/) for secure VPN connectivity
- [Podman](https://podman.io/) for container management
- [GitHub Actions](https://github.com/features/actions) for CI/CD automation 