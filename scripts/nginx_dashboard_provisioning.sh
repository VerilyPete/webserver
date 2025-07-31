#!/bin/bash

echo "=== Creating nginx dashboard for provisioning ==="

# Create a custom nginx dashboard JSON with correct instance reference
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
        "targets": [
          {
            "expr": "nginx_up{instance=\"host.containers.internal:9113\"}",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "green", "value": 1}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Active Connections",
        "type": "stat",
        "targets": [
          {
            "expr": "nginx_connections_active{instance=\"host.containers.internal:9113\"}",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0}
      },
      {
        "id": 3,
        "title": "Requests per Second",
        "type": "timeseries",
        "targets": [
          {
            "expr": "irate(nginx_http_requests_total{instance=\"host.containers.internal:9113\"}[5m])",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 4,
        "title": "Connection Rate",
        "type": "timeseries",
        "targets": [
          {
            "expr": "irate(nginx_connections_accepted_total{instance=\"host.containers.internal:9113\"}[5m])",
            "refId": "A",
            "legendFormat": "Accepted"
          },
          {
            "expr": "irate(nginx_connections_handled_total{instance=\"host.containers.internal:9113\"}[5m])",
            "refId": "B",
            "legendFormat": "Handled"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "id": 5,
        "title": "Connection States",
        "type": "timeseries",
        "targets": [
          {
            "expr": "nginx_connections_reading{instance=\"host.containers.internal:9113\"}",
            "refId": "A",
            "legendFormat": "Reading"
          },
          {
            "expr": "nginx_connections_writing{instance=\"host.containers.internal:9113\"}",
            "refId": "B", 
            "legendFormat": "Writing"
          },
          {
            "expr": "nginx_connections_waiting{instance=\"host.containers.internal:9113\"}",
            "refId": "C",
            "legendFormat": "Waiting"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "30s"
  },
  "overwrite": true
}
EOF

echo "✅ Created nginx dashboard with correct instance references"
echo "This dashboard will be automatically provisioned by Grafana"