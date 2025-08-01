#!/bin/bash

echo "=== Fixing monitoring services ==="

# Stop any existing services
systemctl --user stop prometheus.service grafana.service 2>/dev/null

# Get absolute paths
PROMETHEUS_CONFIG=$(realpath prometheus/prometheus.yml)
GRAFANA_PROVISIONING=$(realpath grafana/provisioning)

echo "Fixing systemd service files..."

# Fix Prometheus systemd service (remove invalid --port flag, keep host networking)
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
  --net=host \\
  -v "${PROMETHEUS_CONFIG}:/etc/prometheus/prometheus.yml:ro,Z" \\
  -v prometheus-data:/prometheus \\
  docker.io/prom/prometheus:latest \\
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

# Fix Grafana systemd service (remove invalid --port flag, keep host networking)
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
  --net=host \\
  -v grafana-data:/var/lib/grafana \\
  -v "${GRAFANA_PROVISIONING}:/etc/grafana/provisioning:ro,Z" \\
  -e GF_SECURITY_ADMIN_USER=admin \\
  -e GF_SECURITY_ADMIN_PASSWORD=admin123 \\
  -e GF_USERS_ALLOW_SIGN_UP=false \\
  -e GF_SECURITY_DISABLE_GRAVATAR=true \\
  grafana/grafana:latest

ExecStop=/usr/bin/podman stop grafana
KillMode=mixed
KillSignal=SIGTERM

[Install]
WantedBy=default.target
EOF

# Reload systemd
systemctl --user daemon-reload

echo "✅ Fixed systemd service files"

echo ""
echo "=== Starting services ==="

# Start services
systemctl --user start prometheus.service
sleep 5
systemctl --user start grafana.service

echo "Waiting for services to start..."
sleep 15

# Check status
PROMETHEUS_STATUS=$(systemctl --user is-active prometheus.service)
GRAFANA_STATUS=$(systemctl --user is-active grafana.service)

echo "Prometheus: $PROMETHEUS_STATUS"
echo "Grafana: $GRAFANA_STATUS"

if [ "$PROMETHEUS_STATUS" != "active" ] || [ "$GRAFANA_STATUS" != "active" ]; then
    echo "❌ Services still failing. Let's check detailed logs:"
    echo ""
    echo "=== Prometheus logs ==="
    journalctl --user -u prometheus.service --no-pager -n 20
    echo ""
    echo "=== Grafana logs ==="
    journalctl --user -u grafana.service --no-pager -n 20
    echo ""
    echo "Let's try starting them manually to see the exact error:"
    echo ""
    echo "Testing Prometheus manually..."
    podman run --rm --name prometheus-test \
      --net=host \
      -v "${PROMETHEUS_CONFIG}:/etc/prometheus/prometheus.yml:ro,Z" \
      -v prometheus-data:/prometheus \
      docker.io/prom/prometheus:latest \
      --config.file=/etc/prometheus/prometheus.yml \
      --storage.tsdb.path=/prometheus \
      --storage.tsdb.retention.time=30d \
      --web.enable-lifecycle &

    PROM_PID=$!
    sleep 5
    kill $PROM_PID 2>/dev/null

    exit 1
else
    echo "✅ Services are now running!"
fi

echo ""
echo "=== Testing endpoints ==="

# Test endpoints
curl -s -o /dev/null -w "Prometheus (9090): %{http_code}\\n" http://localhost:9090
curl -s -o /dev/null -w "Grafana (3000): %{http_code}\\n" http://localhost:3000

echo ""
echo "=== Continue with exporters ==="

echo "Starting Node Exporter..."
podman run -d --name node-exporter \
  --restart unless-stopped \
  --net=host \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /:/rootfs:ro \
  docker.io/prom/node-exporter:latest \
  --path.procfs=/host/proc \
  --path.rootfs=/rootfs \
  --path.sysfs=/host/sys \
  --collector.filesystem.mount-points-exclude='^/(sys|proc|dev|host|etc)($|/)'

if [ $? -eq 0 ]; then
    echo "✅ Node Exporter started"
else
    echo "❌ Node Exporter failed"
fi

echo ""
echo "Starting cAdvisor..."
podman run -d --name cadvisor \
  --restart unless-stopped \
  --net=host \
  -v /:/rootfs:ro \
  -v /var/run:/var/run:ro \
  -v /sys:/sys:ro \
  -v /var/lib/containers:/var/lib/containers:ro \
  --privileged \
  gcr.io/cadvisor/cadvisor:latest

if [ $? -eq 0 ]; then
    echo "✅ cAdvisor started (host network, available on port 8080)"
else
    echo "❌ cAdvisor failed"
fi

echo ""
echo "Checking for nginx status endpoint..."
if curl -s http://localhost:8080/nginx_status >/dev/null; then
    echo "✅ nginx status endpoint found"

    echo "Starting nginx-exporter..."
    podman run -d --name nginx-exporter \
      --restart unless-stopped \
      --net=host \
      docker.io/nginx/nginx-prometheus-exporter:latest \
      -nginx.scrape-uri=http://127.0.0.1:8080/nginx_status

    if [ $? -eq 0 ]; then
        echo "✅ nginx-exporter started (host network, available on port 9113)"
    else
        echo "❌ nginx-exporter failed"
    fi
else
    echo "⚠️  nginx status endpoint not found at localhost:8080/nginx_status"
    echo "Make sure your web container exposes port 8080 with nginx status"
fi

echo ""
echo "Restarting Prometheus to pick up new targets..."
systemctl --user restart prometheus.service

sleep 10

echo ""
echo "=== Final Status ==="
echo "All containers:"
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "✅ Monitoring stack should now be running!"
echo "🚀 Access points:"
echo "- Grafana: http://localhost:3000 (admin/admin123)"
echo "- Prometheus: http://localhost:9090"
echo "- Node Exporter: http://localhost:9100"
echo "- cAdvisor: http://localhost:8080"
echo "- nginx-exporter: http://localhost:9113 (if nginx status available)"
