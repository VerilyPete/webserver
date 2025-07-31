#!/bin/bash

echo "=== Complete monitoring setup from scratch ==="
echo "This script sets up the entire monitoring stack:"
echo "- Prometheus + Grafana (systemd services)"
echo "- Node Exporter (system monitoring)"
echo "- cAdvisor (container monitoring)"
echo "- nginx-prometheus-exporter (nginx monitoring)"
echo ""

# Check SELinux and set up if needed
SELINUX_STATUS=$(getenforce)
echo "SELinux status: $SELINUX_STATUS"

if [ "$SELINUX_STATUS" = "Enforcing" ]; then
    echo "Setting up SELinux permissions for containers..."
    sudo setsebool -P container_manage_cgroup true 2>/dev/null || echo "Boolean already set"
    sudo semanage port -a -t http_port_t -p tcp 8080 2>/dev/null || echo "Port 8080 already configured"
    sudo semanage port -a -t http_port_t -p tcp 9113 2>/dev/null || echo "Port 9113 already configured"
fi

echo ""
echo "=== Step 1: Create configuration directories and files ==="

# Create directories
mkdir -p {prometheus,grafana/provisioning/{datasources,dashboards}}

# Create Prometheus configuration
cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # System metrics
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
    scrape_interval: 10s

  # Container metrics  
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
    scrape_interval: 10s

  # Nginx metrics (will be available after your redeploy)
  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx-exporter:9113']
    scrape_interval: 10s
EOF

# Create Grafana datasource provisioning
cat > grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

# Create Grafana dashboard provisioning config
cat > grafana/provisioning/dashboards/dashboard.yml << 'EOF'
apiVersion: 1
providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

# Create nginx dashboard if nginx monitoring will be available
if curl -s http://localhost:8080/nginx_status >/dev/null 2>&1; then
    echo "Creating nginx dashboard..."
    ./create-nginx-dashboard.sh 2>/dev/null || {
        # Inline creation if script doesn't exist
        cat > grafana/provisioning/dashboards/nginx-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "nginx Overview", 
    "tags": ["nginx"],
    "timezone": "UTC",
    "panels": [
      {
        "id": 1,
        "title": "nginx Status",
        "type": "stat",
        "targets": [{"expr": "nginx_up{instance=\"host.containers.internal:9113\"}", "refId": "A"}],
        "fieldConfig": {"defaults": {"color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "red", "value": 0}, {"color": "green", "value": 1}]}}},
        "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Active Connections", 
        "type": "stat",
        "targets": [{"expr": "nginx_connections_active{instance=\"host.containers.internal:9113\"}", "refId": "A"}],
        "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0}
      },
      {
        "id": 3,
        "title": "Requests per Second",
        "type": "timeseries", 
        "targets": [{"expr": "irate(nginx_http_requests_total{instance=\"host.containers.internal:9113\"}[5m])", "refId": "A"}],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      }
    ],
    "time": {"from": "now-1h", "to": "now"},
    "refresh": "30s"
  },
  "overwrite": true
}
EOF
        echo "✅ Created inline nginx dashboard"
    }
fi

echo "✅ Configuration files created"

echo ""
echo "=== Step 2: Create monitoring network and volumes ==="

# Create network and volumes
podman network create monitoring 2>/dev/null || echo "Network monitoring exists"
podman volume create prometheus-data 2>/dev/null || echo "Volume prometheus-data exists"
podman volume create grafana-data 2>/dev/null || echo "Volume grafana-data exists"

echo "✅ Network and volumes ready"

echo ""
echo "=== Step 3: Create systemd services ==="

mkdir -p ~/.config/systemd/user

# Get absolute paths
PROMETHEUS_CONFIG=$(realpath prometheus/prometheus.yml)
GRAFANA_PROVISIONING=$(realpath grafana/provisioning)

# Create Prometheus systemd service
cat > ~/.config/systemd/user/prometheus.service << EOF
[Unit]
Description=Prometheus monitoring system
After=network.target
Wants=network.target

[Service]
Type=simple
Restart=always
RestartSec=5
TimeoutStartSec=60
TimeoutStopSec=30

ExecStartPre=-/usr/bin/podman stop prometheus
ExecStartPre=-/usr/bin/podman rm prometheus

ExecStart=/usr/bin/podman run --rm --name prometheus \\
  -p 9090:9090 \\
  -v "${PROMETHEUS_CONFIG}:/etc/prometheus/prometheus.yml:ro,Z" \\
  -v prometheus-data:/prometheus \\
  --network monitoring \\
  prom/prometheus:latest \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/prometheus \\
  --storage.tsdb.retention.time=30d \\
  --web.enable-lifecycle

ExecStop=/usr/bin/podman stop prometheus
KillMode=mixed
KillSignal=SIGTERM

[Install]
WantedBy=default.target
EOF

# Create Grafana systemd service
cat > ~/.config/systemd/user/grafana.service << EOF
[Unit]
Description=Grafana visualization platform
After=network.target prometheus.service
Wants=network.target
Requires=prometheus.service

[Service]
Type=simple
Restart=always
RestartSec=5
TimeoutStartSec=60
TimeoutStopSec=30

ExecStartPre=-/usr/bin/podman stop grafana
ExecStartPre=-/usr/bin/podman rm grafana

ExecStart=/usr/bin/podman run --rm --name grafana \\
  -p 3000:3000 \\
  -v grafana-data:/var/lib/grafana \\
  -v "${GRAFANA_PROVISIONING}:/etc/grafana/provisioning:ro,Z" \\
  -e GF_SECURITY_ADMIN_USER=admin \\
  -e GF_SECURITY_ADMIN_PASSWORD=admin123 \\
  -e GF_USERS_ALLOW_SIGN_UP=false \\
  -e GF_SECURITY_DISABLE_GRAVATAR=true \\
  --network monitoring \\
  grafana/grafana:latest

ExecStop=/usr/bin/podman stop grafana
KillMode=mixed
KillSignal=SIGTERM

[Install]
WantedBy=default.target
EOF

# Create monitoring target
cat > ~/.config/systemd/user/monitoring.target << 'EOF'
[Unit]
Description=Monitoring Stack (Prometheus + Grafana + Exporters)
Wants=prometheus.service grafana.service
After=prometheus.service grafana.service

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload

echo "✅ Systemd services created"

echo ""
echo "=== Step 4: Start core monitoring services ==="

systemctl --user start prometheus.service
sleep 5
systemctl --user start grafana.service

echo "Waiting for services to start..."
sleep 10

# Check core services
PROMETHEUS_STATUS=$(systemctl --user is-active prometheus.service)
GRAFANA_STATUS=$(systemctl --user is-active grafana.service)

echo "Prometheus: $PROMETHEUS_STATUS"
echo "Grafana: $GRAFANA_STATUS"

if [ "$PROMETHEUS_STATUS" != "active" ] || [ "$GRAFANA_STATUS" != "active" ]; then
    echo "❌ Core services failed to start properly"
    echo "Checking logs..."
    systemctl --user status prometheus.service grafana.service --no-pager -l
    exit 1
fi

echo "✅ Core monitoring services running"

echo ""
echo "=== Step 5: Add system monitoring (Node Exporter) ==="

podman run -d --name node-exporter \
  --restart unless-stopped \
  -p 9100:9100 \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /:/rootfs:ro \
  --network monitoring \
  prom/node-exporter:latest \
  --path.procfs=/host/proc \
  --path.rootfs=/rootfs \
  --path.sysfs=/host/sys \
  --collector.filesystem.mount-points-exclude='^/(sys|proc|dev|host|etc)($$|/)'

if [ $? -eq 0 ]; then
    echo "✅ Node Exporter started"
    NODE_EXPORTER_OK=true
else
    echo "❌ Node Exporter failed"
    NODE_EXPORTER_OK=false
fi

echo ""
echo "=== Step 6: Add container monitoring (cAdvisor) ==="

podman run -d --name cadvisor \
  --restart unless-stopped \
  -p 8888:8080 \
  -v /:/rootfs:ro \
  -v /var/run:/var/run:ro \
  -v /sys:/sys:ro \
  -v /var/lib/containers:/var/lib/containers:ro \
  --network monitoring \
  --privileged \
  gcr.io/cadvisor/cadvisor:latest

if [ $? -eq 0 ]; then
    echo "✅ cAdvisor started on port 8888"
    CADVISOR_OK=true  
else
    echo "❌ cAdvisor failed"
    CADVISOR_OK=false
fi

echo ""
echo "=== Step 7: Add nginx monitoring ==="

# Check if nginx status endpoint is available
echo "Checking for nginx status endpoint..."
if curl -s http://localhost:8080/nginx_status >/dev/null; then
    echo "✅ nginx status endpoint found"
    
    # Connect web container to monitoring network
    podman network connect monitoring web 2>/dev/null || echo "Web container connection may have failed or already connected"
    
    # Start nginx-prometheus-exporter
    podman run -d --name nginx-exporter \
      --restart unless-stopped \
      -p 9113:9113 \
      --network monitoring \
      nginx/nginx-prometheus-exporter:latest \
      -nginx.scrape-uri=http://web:8080/nginx_status
    
    if [ $? -eq 0 ]; then
        echo "✅ nginx-exporter started"
        NGINX_EXPORTER_OK=true
    else
        echo "❌ nginx-exporter failed"
        NGINX_EXPORTER_OK=false
    fi
else
    echo "⚠️  nginx status endpoint not found"
    echo "Make sure your nginx container:"
    echo "- Has the status server block in nginx.conf"
    echo "- Exposes port 8080"
    echo "- Is running and accessible"
    NGINX_EXPORTER_OK=false
fi

echo ""
echo "=== Step 8: Restart Prometheus to load all targets ==="

systemctl --user restart prometheus.service

echo ""
echo "=== Step 9: Auto-restore Grafana dashboards if backup exists ==="

# Look for any grafana backup directories
BACKUP_DIR=$(ls -d grafana-backup-* 2>/dev/null | head -1)

if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
    echo "Found Grafana backup: $BACKUP_DIR"
    echo "Waiting for Grafana to be fully ready..."
    
    # Wait longer for Grafana to be completely ready
    sleep 20
    
    # Check if restore script exists and run it
    if [ -f "$BACKUP_DIR/restore-dashboards.sh" ]; then
        echo "Running dashboard restore..."
        cd "$BACKUP_DIR"
        ./restore-dashboards.sh
        cd ..
        echo "✅ Dashboard restore completed"
    else
        echo "⚠️  No restore script found in backup"
    fi
else
    echo "ℹ️  No Grafana backup found - will import default nginx dashboard"
    
    # Wait for Grafana to be ready
    echo "Waiting for Grafana to be ready for dashboard import..."
    for i in {1..30}; do
        if curl -s -u admin:admin123 http://localhost:3000/api/health >/dev/null 2>&1; then
            break
        fi
        echo "Waiting... ($i/30)"
        sleep 2
    done
    
    if [ "$NGINX_EXPORTER_OK" = true ]; then
        echo "Importing and fixing nginx dashboard..."
        
        # Download the nginx dashboard JSON
        curl -s "https://grafana.com/api/dashboards/12708/revisions/1/download" > /tmp/nginx-dashboard.json
        
        if [ -f /tmp/nginx-dashboard.json ]; then
            # Fix the template variables for our setup
            sed -i 's/"query": "label_values(nginx_up, instance)"/"query": "host.containers.internal:9113"/' /tmp/nginx-dashboard.json
            sed -i 's/"regex": ".*"/"regex": "host.containers.internal:9113"/' /tmp/nginx-dashboard.json
            sed -i 's/"multi": true/"multi": false/' /tmp/nginx-dashboard.json
            sed -i 's/"includeAll": true/"includeAll": false/' /tmp/nginx-dashboard.json
            
            # Also fix any hardcoded $instance references that might cause issues
            sed -i 's/\$instance/host.containers.internal:9113/g' /tmp/nginx-dashboard.json
            
            # Import the fixed dashboard
            echo "Importing fixed nginx dashboard..."
            curl -s -u admin:admin123 -H "Content-Type: application/json" \
                -d @/tmp/nginx-dashboard.json \
                "http://localhost:3000/api/dashboards/db" >/dev/null
            
            if [ $? -eq 0 ]; then
                echo "✅ nginx dashboard imported and fixed"
            else
                echo "⚠️  Dashboard import may have failed"
            fi
            
            rm -f /tmp/nginx-dashboard.json
        else
            echo "⚠️  Could not download nginx dashboard"
        fi
    fi
fi

echo ""
echo "=== Step 10: Final verification ==="

sleep 15

echo "All containers:"
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(prometheus|grafana|node-exporter|cadvisor|nginx-exporter|web)"

echo ""
echo "Service endpoints:"
curl -s -o /dev/null -w "Website (8081): %{http_code}\\n" http://localhost:8081
curl -s -o /dev/null -w "Prometheus (9090): %{http_code}\\n" http://localhost:9090
curl -s -o /dev/null -w "Grafana (3000): %{http_code}\\n" http://localhost:3000

if [ "$NODE_EXPORTER_OK" = true ]; then
    curl -s -o /dev/null -w "Node Exporter (9100): %{http_code}\\n" http://localhost:9100
fi
if [ "$CADVISOR_OK" = true ]; then
    curl -s -o /dev/null -w "cAdvisor (8888): %{http_code}\\n" http://localhost:8888
fi
if [ "$NGINX_EXPORTER_OK" = true ]; then
    curl -s -o /dev/null -w "nginx-exporter (9113): %{http_code}\\n" http://localhost:9113
    curl -s -o /dev/null -w "nginx status (8080): %{http_code}\\n" http://localhost:8080/nginx_status
fi

echo ""
echo "Prometheus targets:"
curl -s http://localhost:9090/api/v1/targets | grep -o '"health":"[^"]*"' | sort | uniq -c

echo ""
echo "=== COMPLETE! ==="
echo ""
echo "🎉 Your full monitoring stack is now running:"
echo "✅ Prometheus (metrics collection)"
echo "✅ Grafana (visualization)"
if [ "$NODE_EXPORTER_OK" = true ]; then
    echo "✅ Node Exporter (system metrics)"
fi
if [ "$CADVISOR_OK" = true ]; then
    echo "✅ cAdvisor (container metrics)"
fi
if [ "$NGINX_EXPORTER_OK" = true ]; then
    echo "✅ nginx-exporter (nginx metrics)"
fi

echo ""
echo "🚀 Next steps:"
echo "1. Access Grafana: http://localhost:3000 (admin/admin123)"
echo "2. Import dashboards:"
echo "   - System monitoring: Dashboard ID 1860"
echo "   - Container monitoring: Dashboard ID 893"
if [ "$NGINX_EXPORTER_OK" = true ]; then
    echo "   - nginx monitoring: Dashboard ID 12708"
fi
echo "3. Check Prometheus: http://localhost:9090/targets"

echo ""
echo "🔧 Enable auto-start (optional):"
echo "systemctl --user enable prometheus.service grafana.service"
echo "sudo loginctl enable-linger \$USER  # Start on boot"

echo ""
echo "✨ You're back to where you were, plus proper nginx monitoring!"