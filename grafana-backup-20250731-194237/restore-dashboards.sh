#!/bin/bash
echo "=== Restoring Grafana Dashboards ==="

# Wait for Grafana to be ready
echo "Waiting for Grafana to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 2
done

# Import dashboards
if [ -f "dashboard-uids.txt" ]; then
    echo "Restoring dashboards..."
    while read -r uid; do
        if [ -n "$uid" ] && [ -f "dashboard-$uid.json" ]; then
            echo "Importing dashboard: $uid"
            
            # Extract dashboard JSON and prepare for import
            DASHBOARD_JSON=$(cat "dashboard-$uid.json" | jq '.dashboard')
            
            if [ "$DASHBOARD_JSON" != "null" ]; then
                # Create import payload
                echo "{\"dashboard\": $DASHBOARD_JSON, \"overwrite\": true}" | \
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
    echo "⚠️  No dashboard UIDs file found"
fi
