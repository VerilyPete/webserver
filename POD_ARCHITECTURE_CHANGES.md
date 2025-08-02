# Pod Architecture Changes - GitHub Actions Workflow

## Overview

The `refactor-pods.yml` workflow has been updated to deploy a complete pod-based monitoring architecture instead of the previous single-container approach. This new architecture provides better service isolation, networking, and monitoring capabilities.

## New Architecture

### Pod Structure
```
monitoring-net (10.10.0.0/24)
├── webserver-pod
│   ├── nginx (web server) → port 80
│   ├── nginx-exporter (metrics) → port 9113  
│   └── cloudflared (tunnel - optional)
└── monitoring-pod
    ├── prometheus (metrics collection) → port 9090
    └── grafana (visualization) → port 3000

host network (for system access)
├── node-exporter (system metrics) → port 9100
├── cadvisor (container metrics) → port 8080
└── tailscale (VPN - unchanged)
```

### Service Discovery
- **Pod-to-pod**: Use pod names (e.g., `http://webserver-pod:9113`)
- **Within pods**: Use container names (e.g., `http://prometheus:9090`)
- **Pod-to-host**: Use `host.containers.internal:PORT`

## Key Changes Made

### 1. Network Architecture
- **Created**: `monitoring-net` network (10.10.0.0/24) for pod communication
- **Isolated**: Web and monitoring services in their own network namespace
- **Preserved**: Host networking for system monitoring services

### 2. Pod Organization
- **webserver-pod**: Groups web-related services together
  - nginx (main web server)
  - nginx-exporter (web metrics)
  - cloudflared (optional tunnel)
- **monitoring-pod**: Groups monitoring services together
  - prometheus (metrics collection)
  - grafana (visualization)

### 3. Configuration Management
All configurations are now generated dynamically in the workflow:

#### nginx Configuration
- Added `/nginx_status` endpoint for monitoring
- Security headers and proper access controls
- Dual-server setup (main + monitoring)

#### Prometheus Configuration
- Updated target discovery for pod networking
- Proper service discovery endpoints
- Retention and performance settings

#### Grafana Configuration
- Auto-provisioned Prometheus datasource
- Dashboard provisioning setup
- Secure defaults (admin/admin123)

### 4. Deployment Scripts
Created modular deployment scripts:
- `setup-pod-architecture.sh` - Network and config setup
- `start-webserver-pod.sh` - Web services deployment
- `start-monitoring-pod.sh` - Monitoring services deployment  
- `start-standalone-services.sh` - System monitoring services

### 5. Health Verification
Enhanced verification includes:
- Pod status checks
- Network connectivity tests
- Service health endpoints
- Multi-service validation

## Service Access

After deployment, services are accessible at:

| Service | URL | Credentials |
|---------|-----|-------------|
| Website | http://localhost:8081 | - |
| Prometheus | http://localhost:9090 | - |
| Grafana | http://localhost:3000 | admin/admin123 |
| Node Exporter | http://localhost:9100/metrics | - |
| cAdvisor | http://localhost:8080 | - |
| nginx Metrics | http://localhost:9113/metrics | - |
| nginx Status | http://localhost:8080/nginx_status | - |

## Benefits

### 1. Better Isolation
- Services grouped by function
- Network isolation between pods
- Resource management per pod

### 2. Improved Monitoring
- Complete metrics collection pipeline
- Pre-configured Grafana dashboards
- Service health monitoring

### 3. Easier Management
- Pod-level start/stop operations
- Grouped logging and debugging
- Simplified service dependencies

### 4. Scalability
- Easy to add new services to existing pods
- Network policies can be applied per pod
- Resource limits can be set per pod

## Deployment Process

The workflow now:

1. **Creates network infrastructure**
   - `monitoring-net` network
   - Persistent volumes for data

2. **Generates configurations**
   - nginx with monitoring endpoints
   - Prometheus with pod targets
   - Grafana with auto-provisioning

3. **Deploys services in order**
   - Standalone services (node-exporter, cadvisor)
   - Webserver pod (nginx, nginx-exporter, cloudflared)
   - Monitoring pod (prometheus, grafana)

4. **Verifies deployment**
   - Pod health checks
   - Service endpoint validation
   - Network connectivity tests

## Backwards Compatibility

- **Preserved**: All existing external access ports
- **Preserved**: Tailscale VPN functionality
- **Preserved**: Cloudflare tunnel integration
- **Preserved**: systemd service management
- **Enhanced**: Added monitoring capabilities

## Configuration Files

All configurations are generated in `/home/opc/webserver/config/`:
```
config/
├── prometheus/
│   └── prometheus.yml
├── grafana/
│   └── provisioning/
│       ├── datasources/prometheus.yml
│       └── dashboards/dashboard.yml
└── nginx/
    └── nginx.conf
```

## Troubleshooting

### Common Issues
1. **Pods won't start**: Check network creation
2. **Services unreachable**: Verify pod networking
3. **Metrics not collected**: Check Prometheus targets
4. **Grafana can't connect**: Verify datasource configuration

### Debug Commands
```bash
# Check pod status
podman pod ps

# Check network
podman network ls
podman network inspect monitoring-net

# Check service health
curl http://localhost:9090/-/healthy
curl http://localhost:3000/api/health
```

## Future Enhancements

The new architecture enables:
- Easy addition of new monitoring services
- Implementation of network policies
- Resource limits and quotas per pod
- Service mesh integration if needed
- Advanced logging aggregation

This pod architecture provides a more robust, scalable, and maintainable infrastructure while preserving all existing functionality.