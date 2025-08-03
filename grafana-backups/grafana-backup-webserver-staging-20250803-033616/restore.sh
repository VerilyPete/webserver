#!/bin/bash
set -euo pipefail

echo "=== Grafana Restore Starting ==="

# Show what files we have available for restore
echo "📋 Available restore files:"
ls -la

# Wait for Grafana to be ready
echo "Waiting for Grafana to be ready..."
for i in {1..60}; do
  HEALTH_RESPONSE=$(curl -s -u admin:admin123 http://localhost:3000/api/health 2>&1)
  if echo "$HEALTH_RESPONSE" | grep -q "ok\|database"; then
    echo "✅ Grafana is ready"
    echo "Health response: $HEALTH_RESPONSE"
    break
  fi
  if [ $i -eq 60 ]; then
    echo "❌ Grafana not ready after 2 minutes"
    echo "Last health response: $HEALTH_RESPONSE"
    exit 1
  fi
  echo "Waiting... ($i/60) - Health response: $HEALTH_RESPONSE"
  sleep 2
done

# Show current state before restore
echo "📊 Current state before restore:"
CURRENT_DASHBOARDS=$(curl -s -u admin:admin123 "http://localhost:3000/api/search?type=dash-db" 2>/dev/null | jq length || echo "0")
echo "Current dashboards: $CURRENT_DASHBOARDS"

# Restore datasources first
if [ -f "datasources.json" ] && [ "$(jq length datasources.json 2>/dev/null || echo 0)" -gt 0 ]; then
  echo "🔧 Restoring datasources..."
  DATASOURCE_COUNT=0
  jq -c '.[]' datasources.json | while read -r datasource; do
    DATASOURCE_NAME=$(echo "$datasource" | jq -r '.name')
    echo "  📝 Importing datasource: $DATASOURCE_NAME"

    RESPONSE=$(echo "$datasource" | curl -s -u admin:admin123 -H "Content-Type: application/json" \
      -d @- "http://localhost:3000/api/datasources" -w "%{http_code}" 2>&1)

    HTTP_CODE=$(echo "$RESPONSE" | tail -c 4)
    RESPONSE_BODY=$(echo "$RESPONSE" | head -c -4)

    if [[ "$HTTP_CODE" =~ ^2[0-9][0-9]$ ]]; then
      echo "    ✅ Success ($HTTP_CODE): $DATASOURCE_NAME"
      DATASOURCE_COUNT=$((DATASOURCE_COUNT + 1))
    else
      echo "    ⚠️  Response ($HTTP_CODE): $RESPONSE_BODY"
    fi
  done
  echo "✅ Datasource restore completed"
else
  echo "⚠️  No datasources to restore"
fi

# Small delay to ensure datasources are ready
sleep 2

# Restore dashboards
if [ -f "dashboard-uids.txt" ] && [ -s "dashboard-uids.txt" ]; then
  echo "📊 Restoring dashboards..."
  TOTAL_DASHBOARDS=$(wc -l < "dashboard-uids.txt")
  IMPORTED_COUNT=0
  echo "  Total dashboards to import: $TOTAL_DASHBOARDS"

  while read -r uid; do
    if [ -n "$uid" ] && [ -f "dashboard-$uid.json" ]; then
      echo "  📝 Importing dashboard: $uid"

      # Validate dashboard JSON first
      DASHBOARD_JSON=$(cat "dashboard-$uid.json" | jq '.dashboard' 2>/dev/null)
      if [ "$DASHBOARD_JSON" = "null" ] || [ -z "$DASHBOARD_JSON" ]; then
        echo "    ❌ Invalid dashboard JSON for: $uid"
        continue
      fi

      # Create import payload and send to Grafana
      IMPORT_PAYLOAD=$(echo "{\"dashboard\": $DASHBOARD_JSON, \"overwrite\": true, \"inputs\": []}")
      RESPONSE=$(echo "$IMPORT_PAYLOAD" | curl -s -u admin:admin123 -H "Content-Type: application/json" \
        -d @- "http://localhost:3000/api/dashboards/db" -w "%{http_code}" 2>&1)

      HTTP_CODE=$(echo "$RESPONSE" | tail -c 4)
      RESPONSE_BODY=$(echo "$RESPONSE" | head -c -4)

      if [[ "$HTTP_CODE" =~ ^2[0-9][0-9]$ ]]; then
        DASHBOARD_TITLE=$(echo "$DASHBOARD_JSON" | jq -r '.title // "Unknown"')
        echo "    ✅ Success ($HTTP_CODE): $uid - $DASHBOARD_TITLE"
        IMPORTED_COUNT=$((IMPORTED_COUNT + 1))
      else
        echo "    ❌ Failed ($HTTP_CODE): $uid"
        echo "    Error details: $RESPONSE_BODY"
      fi
    else
      echo "  ⚠️  Dashboard file not found: dashboard-$uid.json"
    fi
  done < "dashboard-uids.txt"

  echo "✅ Dashboard restore completed: $IMPORTED_COUNT/$TOTAL_DASHBOARDS imported"
else
  echo "⚠️  No dashboards to restore"
fi

# Show final state after restore
echo "📊 Final state after restore:"
FINAL_DASHBOARDS=$(curl -s -u admin:admin123 "http://localhost:3000/api/search?type=dash-db" 2>/dev/null | jq length || echo "0")
echo "Final dashboard count: $FINAL_DASHBOARDS"

if [ "$FINAL_DASHBOARDS" -gt 0 ]; then
  echo "📋 Restored dashboards:"
  curl -s -u admin:admin123 "http://localhost:3000/api/search?type=dash-db" 2>/dev/null | \
    jq -r '.[] | "  - " + .title + " (" + .uid + ")"' || echo "Could not list dashboards"
fi

echo "=== Grafana Restore Completed ==="
