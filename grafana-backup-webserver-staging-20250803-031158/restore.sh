#!/bin/bash
set -euo pipefail

echo "=== Grafana Restore Starting ==="

# Wait for Grafana to be ready
echo "Waiting for Grafana to be ready..."
for i in {1..60}; do
  if curl -s -u admin:admin123 http://localhost:3000/api/health >/dev/null 2>&1; then
    echo "✅ Grafana is ready"
    break
  fi
  if [ $i -eq 60 ]; then
    echo "❌ Grafana not ready after 2 minutes"
    exit 1
  fi
  echo "Waiting... ($i/60)"
  sleep 2
done

# Restore datasources first
if [ -f "datasources.json" ] && [ "$(jq length datasources.json)" -gt 0 ]; then
  echo "Restoring datasources..."
  jq -c '.[]' datasources.json | while read -r datasource; do
    echo "Importing datasource: $(echo "$datasource" | jq -r '.name')"
    echo "$datasource" | curl -s -u admin:admin123 -H "Content-Type: application/json" \
      -d @- "http://localhost:3000/api/datasources" >/dev/null || true
  done
  echo "✅ Datasources restored"
fi

# Restore dashboards
if [ -f "dashboard-uids.txt" ] && [ -s "dashboard-uids.txt" ]; then
  echo "Restoring dashboards..."
  while read -r uid; do
    if [ -n "$uid" ] && [ -f "dashboard-$uid.json" ]; then
      echo "Importing dashboard: $uid"

      DASHBOARD_JSON=$(cat "dashboard-$uid.json" | jq '.dashboard')
      if [ "$DASHBOARD_JSON" != "null" ]; then
        echo "{\"dashboard\": $DASHBOARD_JSON, \"overwrite\": true, \"inputs\": []}" | \
        curl -s -u admin:admin123 -H "Content-Type: application/json" \
        -d @- "http://localhost:3000/api/dashboards/db" >/dev/null

        if [ $? -eq 0 ]; then
          echo "✅ Imported: $uid"
        else
          echo "❌ Failed to import: $uid"
        fi
      fi
    fi
  done < "dashboard-uids.txt"
  echo "✅ Dashboard restore completed"
else
  echo "⚠️  No dashboards to restore"
fi

echo "=== Grafana Restore Completed ==="
