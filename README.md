# 🚀 Webserver Infrastructure

[![Build and Push](https://github.com/VerilyPete/webserver/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/VerilyPete/webserver/actions/workflows/build-and-push.yml)
[![Deploy](https://github.com/VerilyPete/webserver/actions/workflows/deploy-pods.yml/badge.svg)](https://github.com/VerilyPete/webserver/actions/workflows/deploy-pods.yml)

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
- ✅ **Automatic cache purging** via Cloudflare API after deployments
- ✅ **Cost-effective** ARM-based OCI instances

### What It Does

The infrastructure automatically:
1. Creates or updates OCI compute instances
2. Bootstraps instances with cloud-init configuration
3. Establishes secure Tailscale VPN connectivity
4. Deploys pod-based containerized architecture
5. Configures reverse proxy and optional tunnels
6. Provides comprehensive monitoring and alerting
7. Sets up automated maintenance and health checks

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────────────────┐
│   GitHub Repo   │    │   GitHub Actions │    │         OCI Instance            │
│                 │    │                  │    │                                 │
│ ┌─────────────┐ │    │ ┌──────────────┐ │    │ ┌─────────────────────────────┐ │
│ │ Web Content │ │    │ │ Build Image  │ │    │ │      Cloud-init Bootstrap   │ │
│ │             │ │    │ │              │ │    │ └─────────────────────────────┘ │
│ └─────────────┘ │    │ └──────────────┘ │    │                                 │
└─────────────────┘    └──────────────────┘    │ monitoring-net (10.10.0.0/24)  │
                                │                │ ┌─────────────────────────────┐ │
                                ▼                │ │       webserver-pod         │ │
                       ┌──────────────────┐    │ │ ┌─────────┬─────────────────┐ │ │
                       │Container Registry│    │ │ │ nginx   │ nginx-exporter  │ │ │
                       │      (GHCR)      │    │ │ │ :80     │ :9113           │ │ │
                       └──────────────────┘    │ │ └─────────┴─────────────────┘ │ │
                                                │ │ ┌─────────────────────────────┐ │ │
                                                │ │ │     cloudflared (optional)  │ │ │
                                                │ │ └─────────────────────────────┘ │ │
                                                │ └─────────────────────────────┘ │
                                                │ ┌─────────────────────────────┐ │
                                                │ │      monitoring-pod         │ │
                                                │ │ ┌─────────┬─────────────────┐ │ │
                                                │ │ │prometheus│    grafana      │ │ │
                                                │ │ │ :9090   │    :3000        │ │ │
                                                │ │ └─────────┴─────────────────┘ │ │
                                                │ └─────────────────────────────┘ │
                                                │                                 │
                                                │ host network                    │
                                                │ ┌─────────────────────────────┐ │
                                                │ │ tailscale │ node-exporter   │ │
                                                │ │           │ :9100           │ │
                                                │ └─────────────────────────────┘ │
                                                └─────────────────────────────────┘
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
- Firewall configuration for k0s ports (6443, 9443, 8132, 8133, 10250, 179, 2379-2380, 30000-32767)

## 🚀 Quick Start

### For New Deployments

1. **Configure GitHub Secrets** (see [Configuration](#configuration) section)
2. **Navigate to GitHub Actions** in your repository
3. **Run the "Deploy Pods" workflow**
4. **Select parameters**:
   - **Deployment type**: `fresh_deploy`
   - **Target hostname**: `webserver-staging` or `webserver-prod`
5. **Monitor the deployment** in the Actions tab

### For Updates

1. **Navigate to GitHub Actions** in your repository
2. **Run the "Deploy Pods" workflow**
3. **Select parameters**:
   - **Deployment type**: `update`
   - **Target hostname**: `webserver-staging` or `webserver-prod`
4. **Wait for completion** (typically ~40 seconds on a single OCPU Ampere A1 instance)

### For Web-Only Updates

For the fastest deployments when you only need to update the web application:

1. **Navigate to GitHub Actions** in your repository
2. **Run the "Deploy Pods" workflow**
3. **Select parameters**:
   - **Deployment type**: `web_only_update`
   - **Target hostname**: `webserver-staging` or `webserver-prod`
4. **Wait for completion** (typically ~10-15 seconds)

**Note**: This option only updates the web container image and skips all infrastructure setup. Use this when you only have web application changes and no configuration updates.

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
CLOUDFLARE_PROD_TUNNEL_TOKEN    # Production tunnel token
CLOUDFLARE_STAGING_TUNNEL_TOKEN # Staging tunnel token
CLOUDFLARE_PROD_API_TOKEN       # Production API token for cache purging
CLOUDFLARE_PROD_ZONE_ID         # Production zone ID for cache purging
CLOUDFLARE_STAGING_API_TOKEN    # Staging API token for cache purging
CLOUDFLARE_STAGING_ZONE_ID      # Staging zone ID for cache purging
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
   - Sets up pod architecture scripts
   - Configures monitoring network

5. **Pod Architecture Deployment**
   - Creates monitoring network (10.10.0.0/24)
   - Generates dynamic configuration files
   - Deploys standalone monitoring services
   - Creates webserver pod with nginx and metrics
   - Creates monitoring pod with Prometheus and Grafana
   - Configures optional Cloudflare tunnel

6. **Verification & Health Checks**
   - Validates pod status and networking
   - Checks all service endpoints
   - Confirms monitoring data collection
   - Verifies systemd service integration

7. **Cloudflare Cache Purging**
   - Automatically purges Cloudflare cache after successful deployment
   - Uses environment-specific API credentials (prod/staging)
   - Purges entire cache to ensure fresh content delivery
   - Fails deployment if cache purge fails

### Deployment Timeline

- **Fresh Deploy**: ~5 minutes
- **Update**: ~40 seconds
- **Web-Only Update**: ~10-15 seconds
- **Build Time**: ~45 seconds (parallel)

## 🐳 Container Architecture

### Pod Structure

```
monitoring-net (10.10.0.0/24)
├── webserver-pod
│   ├── nginx (web server) → port 80 (exposed 8081)
│   ├── nginx-exporter (metrics) → port 9113  
│   └── cloudflared (tunnel - optional)
└── monitoring-pod
    ├── prometheus (metrics collection) → port 9090
    └── grafana (visualization) → port 3000

host network (for system access)
├── node-exporter (system metrics) → port 9100
└── tailscale (VPN - unchanged)
```

### Container Details

#### Web Container (webserver-pod)
- **Base Image**: `ghcr.io/verilypete/webserver:latest`
- **Port**: 80 (exposed as 8081)
- **Features**:
  - Static file serving
  - Formspree proxy integration
  - Caching headers
  - Error page handling
  - nginx status endpoint (:8082)

#### nginx-exporter Container (webserver-pod)
- **Base Image**: `nginx/nginx-prometheus-exporter:latest`
- **Port**: 9113
- **Purpose**: Exports nginx metrics for Prometheus
- **Scrapes**: nginx status endpoint

#### Prometheus Container (monitoring-pod)
- **Base Image**: `prom/prometheus:latest`
- **Port**: 9090
- **Features**:
  - Metrics collection from all exporters
  - 30-day retention
  - Service discovery configuration

#### Grafana Container (monitoring-pod)
- **Base Image**: `grafana/grafana:latest`
- **Port**: 3000
- **Features**:
  - Pre-configured Prometheus datasource
  - Dashboard provisioning
  - Admin access (admin/admin123)

#### System Monitoring Services (host network)
- **node-exporter**: System metrics (CPU, memory, disk)

- **tailscale**: VPN connectivity (unchanged)

#### Cloudflared Container (Optional)
- **Purpose**: Public access tunnel
- **Configuration**: Environment-based tunnel token
- **Features**: Automatic reconnection, load balancing

### Volume Mounts

- **nginx.conf**: Dynamic configuration with Formspree endpoint and monitoring
- **prometheus.yml**: Auto-generated with pod networking targets
- **grafana provisioning**: Auto-configured datasources and dashboards
- **prometheus-data**: Persistent metrics storage (30-day retention)
- **grafana-data**: Persistent dashboard and user data
- **tailscale-data**: Persistent VPN state
- **Website Content**: Built into container image

## 📊 Monitoring & Maintenance

The pod architecture provides comprehensive monitoring with Prometheus metrics collection and Grafana visualization. All services are monitored with automated health checks and alerting capabilities.

### Service Access

After deployment, services are accessible at:

| Service | URL | Credentials | Purpose |
|---------|-----|-------------|---------|
| Website | http://localhost:8081 | - | Main web application |
| Prometheus | http://localhost:9090 | - | Metrics collection and querying |
| Grafana | http://localhost:3000 | admin/admin123 | Dashboards and visualization |
| Node Exporter | http://localhost:9100/metrics | - | System metrics |

| nginx Metrics | http://localhost:9113/metrics | - | Web server metrics |
| nginx Status | http://localhost:8082/nginx_status | - | Web server status |

### Monitoring Architecture

The monitoring system collects metrics from multiple sources:

1. **System Metrics** (node-exporter)
   - CPU usage and load
   - Memory utilization
   - Disk I/O and space
   - Network statistics



3. **Web Server Metrics** (nginx-exporter)
   - HTTP request rates
   - Response times
   - Error rates
   - Active connections

4. **Application Metrics** (Prometheus)
   - Service availability
   - Response codes
   - Custom application metrics

### Health Checks

```bash
# Check pod status
ssh opc@[hostname] 'podman pod ps'

# Check all containers
ssh opc@[hostname] 'podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# Check systemd service
ssh opc@[hostname] 'systemctl --user status webserver-pod.service'

# Health endpoint checks
ssh opc@[hostname] 'curl -s http://localhost:8081'           # Website
ssh opc@[hostname] 'curl -s http://localhost:9090/-/healthy' # Prometheus
ssh opc@[hostname] 'curl -s http://localhost:3000/api/health' # Grafana
ssh opc@[hostname] 'curl -s http://localhost:9100/metrics | head -5' # Node exporter

ssh opc@[hostname] 'curl -s http://localhost:9113/metrics | head -5' # nginx exporter

# Check logs
ssh opc@[hostname] 'journalctl --user -u webserver-pod.service -f'
```

### Automated Maintenance

The infrastructure includes automated cleanup and monitoring:

- **Container Cleanup**: Daily removal of unused containers/images via cron
- **Log Rotation**: Automatic log management and archival
- **Health Monitoring**: Continuous health checks via Prometheus
- **Metrics Retention**: 30-day metrics storage with automatic cleanup
- **System Updates**: Periodic security updates

### Manual Maintenance

```bash
# Update entire pod architecture
ssh opc@[hostname] 'cd ~/webserver && git pull && systemctl --user restart webserver-pod.service'

# View pod and container logs
ssh opc@[hostname] 'podman logs web'              # Web server logs
ssh opc@[hostname] 'podman logs nginx-exporter'   # nginx metrics logs
ssh opc@[hostname] 'podman logs prometheus'       # Metrics collection logs
ssh opc@[hostname] 'podman logs grafana'          # Dashboard logs
ssh opc@[hostname] 'podman logs cloudflared'      # Tunnel logs (if enabled)

# Restart individual services
ssh opc@[hostname] 'systemctl --user restart webserver-pod.service'

# Restart individual pods (emergency)
ssh opc@[hostname] 'podman pod restart webserver-pod'
ssh opc@[hostname] 'podman pod restart monitoring-pod'

# Check network connectivity between pods
ssh opc@[hostname] 'podman exec -it prometheus curl http://webserver-pod:9113/metrics'

# Monitor resource usage
ssh opc@[hostname] 'podman pod stats'
ssh opc@[hostname] 'podman stats'
```

## 🔧 Troubleshooting

### Common Issues

#### Pod Startup Failures

**Symptoms**: Pods won't start, containers fail to launch

**Solutions**:
```bash
# Check pod status
ssh opc@[hostname] 'podman pod ps'

# Check network creation
ssh opc@[hostname] 'podman network ls'
ssh opc@[hostname] 'podman network inspect monitoring-net'

# Check container logs
ssh opc@[hostname] 'podman logs web'
ssh opc@[hostname] 'podman logs prometheus'
ssh opc@[hostname] 'podman logs grafana'

# Restart entire pod architecture
ssh opc@[hostname] 'systemctl --user restart webserver-pod.service'
```

#### Network Connectivity Issues

**Symptoms**: Services can't communicate, metrics not collected

**Solutions**:
```bash
# Test pod-to-pod connectivity
ssh opc@[hostname] 'podman exec -it prometheus curl http://webserver-pod:9113/metrics'

# Check network configuration
ssh opc@[hostname] 'podman network inspect monitoring-net'

# Verify service discovery
ssh opc@[hostname] 'podman exec -it prometheus curl http://localhost:9090/api/v1/targets'

# Check pod networking
ssh opc@[hostname] 'podman exec -it web curl http://host.containers.internal:9100/metrics'
```

#### Monitoring Services Unreachable

**Symptoms**: Grafana can't connect to Prometheus, dashboards empty

**Solutions**:
```bash
# Check Prometheus health
ssh opc@[hostname] 'curl http://localhost:9090/-/healthy'

# Check Grafana datasource
ssh opc@[hostname] 'curl http://localhost:3000/api/health'

# Verify configuration files
ssh opc@[hostname] 'cat ~/webserver/config/prometheus/prometheus.yml'
ssh opc@[hostname] 'cat ~/webserver/config/grafana/provisioning/datasources/prometheus.yml'

# Restart monitoring pod
ssh opc@[hostname] 'podman pod restart monitoring-pod'
```

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

**Symptoms**: Individual containers fail within pods

**Solutions**:
```bash
# Check specific container logs
ssh opc@[hostname] 'podman logs nginx-exporter'
ssh opc@[hostname] 'podman logs node-exporter'

# Check service status
ssh opc@[hostname] 'systemctl --user status webserver-pod.service'

# Check container restart counts
ssh opc@[hostname] 'podman ps --format "table {{.Names}}\t{{.Status}}\t{{.RestartCount}}"'
```

#### K0s Firewall Port Requirements

The k0s cluster requires specific firewall ports to be open for proper operation:

#### Controller Node Ports
```bash
# Essential k0s ports
6443/tcp   # Kubernetes API server
9443/tcp   # k0s controller join API  
8132/tcp   # Konnectivity server
8133/tcp   # Konnectivity admin port
10250/tcp  # Kubelet API
2379/tcp   # etcd client API
2380/tcp   # etcd peer communication
179/tcp    # Kube-router BGP

# Service ports  
30000-32767/tcp # NodePort services (if used)
```

#### Worker Node Ports
```bash
# Essential worker ports
10250/tcp  # Kubelet API
8132/tcp   # Konnectivity agent
179/tcp    # Kube-router BGP
30000-32767/tcp # NodePort services
```

### Konnectivity Issues (k0s deployments)

**Symptoms**: kubectl exec fails, pods can't communicate with API server

**Solutions**:
```bash
# Check konnectivity-agent pods status
ssh opc@k8s-controller 'sudo /usr/local/bin/k0s kubectl get pods -n kube-system | grep konnectivity'

# Check if konnectivity port is blocked by firewall
ssh opc@k8s-controller 'sudo firewall-cmd --list-ports | grep 8132'

# Add konnectivity port if missing
ssh opc@k8s-controller 'sudo firewall-cmd --permanent --add-port=8132/tcp && sudo firewall-cmd --reload'

# Verify konnectivity-agents become ready (should show 1/1)
ssh opc@k8s-controller 'sudo /usr/local/bin/k0s kubectl get pods -n kube-system -l app=konnectivity-agent'
```

### Cloud-init Errors

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
5. Verify pod architecture scripts are executable

### Debug Commands

```bash
# System information
ssh opc@[hostname] 'uname -a && cat /etc/os-release'

# Network connectivity
ssh opc@[hostname] 'ip addr show && ping -c 3 1.1.1.1'

# Pod architecture status
ssh opc@[hostname] 'podman pod ps'
ssh opc@[hostname] 'podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.RestartCount}}"'

# Network debugging
ssh opc@[hostname] 'podman network ls'
ssh opc@[hostname] 'podman network inspect monitoring-net'

# Container resources and stats
ssh opc@[hostname] 'podman system df'
ssh opc@[hostname] 'podman pod stats --no-stream'
ssh opc@[hostname] 'podman stats --no-stream'

# Service status
ssh opc@[hostname] 'systemctl --user list-units --failed'
ssh opc@[hostname] 'systemctl --user status webserver-pod.service'

# Configuration verification
ssh opc@[hostname] 'ls -la ~/webserver/config/'
ssh opc@[hostname] 'find ~/webserver/config/ -type f -exec echo "=== {} ===" \; -exec cat {} \;'

# Health endpoint tests
ssh opc@[hostname] 'curl -s -o /dev/null -w "Web: %{http_code}\n" http://localhost:8081'
ssh opc@[hostname] 'curl -s -o /dev/null -w "Prometheus: %{http_code}\n" http://localhost:9090'
ssh opc@[hostname] 'curl -s -o /dev/null -w "Grafana: %{http_code}\n" http://localhost:3000'
ssh opc@[hostname] 'curl -s -o /dev/null -w "Node Exporter: %{http_code}\n" http://localhost:9100/metrics'

ssh opc@[hostname] 'curl -s -o /dev/null -w "nginx Exporter: %{http_code}\n" http://localhost:9113/metrics'

# Pod networking tests
ssh opc@[hostname] 'podman exec -it prometheus curl -s http://webserver-pod:9113/metrics | head -5'
ssh opc@[hostname] 'podman exec -it web curl -s http://host.containers.internal:9100/metrics | head -5'

# Volume and mount verification
ssh opc@[hostname] 'podman volume ls'
ssh opc@[hostname] 'podman inspect prometheus-data grafana-data'
```

## 🔒 Security

### Network Security

- **Private Subnet**: Instances deployed in private OCI subnet
- **No Public IP**: Instances have no direct internet access
- **VPN Access**: All access via Tailscale mesh network
- **Pod Network Isolation**: Internal monitoring network (10.10.0.0/24) isolates services
- **Firewall Rules**: Minimal port exposure (8081, 9090, 3000 for monitoring)
- **Host Network Services**: System monitoring services isolated on host network

### Container Security

- **Non-root Containers**: All containers run as non-privileged users
- **Pod Security**: Containers within pods share security context
- **SELinux**: Context-aware security policies for all containers
- **Image Scanning**: Built from trusted base images (Docker Hub, GHCR)
- **Secret Management**: Environment-based configuration with restricted access
- **Network Policies**: Pod-to-pod communication on dedicated network

### Access Control

- **Service Authentication**: Grafana requires admin credentials
- **SSH Keys**: Key-based authentication only
- **Tailscale ACLs**: Network-level access control
- **GitHub Secrets**: Encrypted secret storage
- **OCI IAM**: Principle of least privilege
- **Internal Services**: Monitoring services accessible only via Tailscale
- **API Security**: Prometheus and metrics endpoints require network access
- **Container Isolation**: Each service isolated within its pod context

### Data Protection

- **Persistent Volumes**: Encrypted storage for metrics and dashboards (30-day retention)
- **Configuration Security**: Read-only mounted configuration files
- **Log Security**: Centralized logging with rotation and retention policies
- **Backup Strategy**: Automated backup of Grafana dashboards and configuration
- **Encrypted Transit**: All communications encrypted
- **Secret Rotation**: Support for credential rotation
- **Audit Logging**: Comprehensive logging and monitoring via Prometheus

## 🛠️ Development

### Local Development

```bash
# Clone repository
git clone https://github.com/VerilyPete/webserver.git
cd webserver

# Build container locally
cd web
docker build -t webserver:local .

# Test single container
docker run -p 8081:80 webserver:local

# Test full pod architecture locally (requires Podman)
podman network create monitoring-net --subnet=10.10.0.0/24

# Create volumes
podman volume create prometheus-data
podman volume create grafana-data

# Start monitoring services
podman run -d --name node-exporter --network host \
  prom/node-exporter:latest

# Start webserver pod
podman pod create --name webserver-pod --network monitoring-net -p 8081:80 -p 9113:9113
podman run -d --pod webserver-pod --name web webserver:local
podman run -d --pod webserver-pod --name nginx-exporter \
  nginx/nginx-prometheus-exporter:latest -nginx.scrape-uri=http://localhost:8082/nginx_status

# Start monitoring pod
podman pod create --name monitoring-pod --network monitoring-net -p 9090:9090 -p 3000:3000
# (Additional prometheus and grafana setup required)
```

### Testing Changes

1. **Local Container Testing**: Test individual container builds
2. **Local Pod Testing**: Test pod architecture with Podman
3. **Staging Deployment**: Deploy to staging environment (`webserver-staging`)
4. **Monitoring Validation**: Verify all metrics are collected properly
5. **Production Deployment**: Deploy to production (`webserver-prod`) after validation

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

#### Deploy Pods Workflow (`deploy-pods.yml`)
- **Trigger**: Manual dispatch only
- **Parameters**:
  - `deploy_type`: `fresh_deploy`, `update`, or `web_only_update`
  - `hostname`: `webserver-staging` or `webserver-prod`
- **Purpose**: Deploy complete pod-based monitoring infrastructure
- **Features**:
  - Automated network creation (monitoring-net)
  - Pod architecture deployment (webserver-pod, monitoring-pod)
  - Comprehensive health verification
  - Prometheus + Grafana monitoring setup
  - **Automatic Cloudflare cache purging** after successful deployment
    - Production deployments use `CLOUDFLARE_PROD_API_TOKEN` and `CLOUDFLARE_PROD_ZONE_ID`
    - Staging deployments use `CLOUDFLARE_STAGING_API_TOKEN` and `CLOUDFLARE_STAGING_ZONE_ID`
    - Purges entire cache using Cloudflare API v4
    - Deployment fails if cache purge fails
- **Deployment Types**:
  - `fresh_deploy`: Creates new instance with complete infrastructure setup
  - `update`: Updates existing instance with full infrastructure refresh
  - `web_only_update`: Updates only the web container image (fastest option)

#### Grafana Backup & Restore Workflow (`grafana-backup-restore.yml`)
- **Trigger**: Manual dispatch only
- **Parameters**:
  - `operation`: `backup` or `restore`
  - `target_environment`: `webserver-staging` or `webserver-prod`
  - `backup_source`: Source for restore operations
  - `specific_backup`: Exact backup name (optional)
- **Purpose**: Backup and restore Grafana dashboards and configuration
- **Features**:
  - Cross-environment backup/restore (prod ↔ staging)
  - Automated backup storage in `grafana-backups/` folder
  - Dashboard and datasource preservation
  - Timestamped backup naming
  - Complete restore scripts included with each backup

### Container Images

#### Primary Images
- **Web Application**: `ghcr.io/verilypete/webserver:latest`
- **Prometheus**: `prom/prometheus:latest`
- **Grafana**: `grafana/grafana:latest`
- **nginx Exporter**: `nginx/nginx-prometheus-exporter:latest`
- **Node Exporter**: `prom/node-exporter:latest`

- **Cloudflared**: `cloudflare/cloudflared:latest` (optional)
- **Tailscale**: `tailscale/tailscale:latest`

#### Available Tags
- `latest`: Latest stable build
- `main-[commit]`: Branch-specific builds
- `[version]`: Versioned releases

#### Image Variants
- `linux/amd64`: x86_64 architecture
- `linux/arm64`: ARM64 architecture

### Environment Variables

#### Deployment Variables
| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `HOSTNAME` | Instance hostname | Yes | - |
| `TAILSCALE_AUTH_KEY` | Tailscale authentication key | Yes | - |
| `CLOUDFLARE_TUNNEL_TOKEN` | Cloudflare tunnel token | No | - |
| `FORMSPREE_ENDPOINT` | Formspree endpoint URL | Yes | - |
| `APP_PORT` | Web server port | No | 8081 |
| `APP_ENV` | Environment name | No | production |

#### Monitoring Variables
| Variable | Description | Container | Default |
|----------|-------------|-----------|---------|
| `GF_SECURITY_ADMIN_USER` | Grafana admin username | grafana | admin |
| `GF_SECURITY_ADMIN_PASSWORD` | Grafana admin password | grafana | admin123 |
| `GF_USERS_ALLOW_SIGN_UP` | Allow user registration | grafana | false |
| `TUNNEL_TOKEN` | Cloudflare tunnel token | cloudflared | - |

## 💡 Examples

### Basic Pod Architecture Deployment

```yaml
# GitHub Actions workflow example for pod architecture
- name: Deploy Pod Architecture to Staging
  uses: actions/github-script@v6
  with:
    script: |
      github.rest.actions.createWorkflowDispatch({
        owner: 'VerilyPete',
        repo: 'webserver',
        workflow_id: 'refactor-pods.yml',
        ref: 'main',
        inputs: {
          deploy_type: 'update',
          hostname: 'webserver-staging'
        }
      })
```

### Pod Architecture Monitoring

```bash
# Access monitoring services via Tailscale
ssh opc@webserver-staging

# Check all pod services
curl http://localhost:8081                    # Website
curl http://localhost:9090/api/v1/targets     # Prometheus targets
curl http://localhost:3000/api/health         # Grafana health

# Monitor metrics collection
curl http://localhost:9100/metrics | grep node_cpu
curl http://localhost:9113/metrics | grep nginx_http


# Test pod networking
podman exec -it prometheus curl http://webserver-pod:9113/metrics
```

### Grafana Backup & Restore

```yaml
# Backup Grafana from production
- name: Backup Grafana Production
  uses: actions/github-script@v6
  with:
    script: |
      github.rest.actions.createWorkflowDispatch({
        owner: 'VerilyPete',
        repo: 'webserver',
        workflow_id: 'grafana-backup-restore.yml',
        ref: 'main',
        inputs: {
          operation: 'backup',
          target_environment: 'webserver-prod'
        }
      })

# Restore backup to staging
- name: Restore to Staging
  uses: actions/github-script@v6
  with:
    script: |
      github.rest.actions.createWorkflowDispatch({
        owner: 'VerilyPete',
        repo: 'webserver',
        workflow_id: 'grafana-backup-restore.yml',
        ref: 'main',
        inputs: {
          operation: 'restore',
          target_environment: 'webserver-staging',
          backup_source: 'latest-prod'
        }
      })
```

### Custom Pod Configuration

```bash
# Extend monitoring with custom metrics
# Add to prometheus.yml configuration

scrape_configs:
  - job_name: 'custom-app'
    static_configs:
      - targets: ['webserver-pod:8080']
    metrics_path: '/metrics'
    scrape_interval: 30s

# Custom Grafana dashboard
# Add to grafana provisioning
apiVersion: 1
providers:
  - name: 'custom-dashboards'
    type: file
    options:
      path: /var/lib/grafana/dashboards/custom
```

### Manual Grafana Backup/Restore

```bash
# Manual backup via SSH
ssh opc@webserver-prod 'cd ~/webserver && ./scripts/grafana_backup_restore.sh backup'

# List available backups in repository
ls -la grafana-backups/

# Download and restore specific backup
scp -r grafana-backups/grafana-backup-webserver-prod-20240101-120000/ opc@webserver-staging:~/
ssh opc@webserver-staging 'cd ~/grafana-backup-webserver-prod-20240101-120000 && ./restore.sh'
```

### Grafana Backup Storage

All Grafana backups are stored in the `grafana-backups/` directory with:
- **Complete dashboard exports** in JSON format
- **Datasource configurations** for easy restoration
- **Automated restore scripts** for each backup
- **Metadata files** with backup information
- **Cross-environment compatibility** for prod ↔ staging transfers

See `grafana-backups/README.md` for detailed backup management instructions.

### Integration with External Services

```bash
# Cloudflare tunnel integration
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

## 🤝 Support

- **Issues**: [GitHub Issues](https://github.com/VerilyPete/webserver/issues)
- **Discussions**: [GitHub Discussions](https://github.com/VerilyPete/webserver/discussions)
- **Documentation**: This README and inline code comments

## 🙏 Acknowledgments

- [Oracle Cloud Infrastructure](https://www.oracle.com/cloud/) for the cloud platform
- [Tailscale](https://tailscale.com/) for secure VPN connectivity
- [Podman](https://podman.io/) for container management
- [GitHub Actions](https://github.com/features/actions) for CI/CD automation 