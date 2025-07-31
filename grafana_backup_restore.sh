#!/bin/bash

echo "=== Grafana Backup and Restore Utility ==="

BACKUP_DIR="grafana-backup-$(date +%Y%m%d-%H%M%S)"

backup_grafana() {
    echo "=== Backing up Grafana configuration ==="
    
    mkdir -p "$BACKUP_DIR"
    
    # Check if Grafana is running
    if ! curl -s http://localhost:3000 >/dev/null; then
        echo "❌ Grafana not accessible at localhost:3000"
        exit 1
    fi
    
    echo "✅ Grafana is accessible"
    
    # Backup method 1: Export dashboards via API
    echo "Exporting dashboards via API..."
    
    # Get all dashboards
    DASHBOARDS=$(curl -s -u admin:admin123 "http://localhost:3000/api/search?type=dash-db" 2>/dev/null)
    
    if echo "$DASHBOARDS" | grep -q "uid"; then
        echo "$DASHBOARDS" | grep -o '"uid":"[^"]*"' | cut -d'"' -f4 > "$BACKUP_DIR/dashboard-uids.txt"
        
        echo "Found $(wc -l < "$BACKUP_DIR/dashboard-uids.txt") dashboards to backup"
        
        # Export each dashboard
        while read -r uid; do
            if [ -n "$uid" ]; then
                echo "Exporting dashboard: $uid"
                curl -s -u admin:admin123 "http://localhost:3000/api/dashboards/uid/$uid" > "$BACKUP_DIR/dashboard-$uid.json"
            fi
        done < "$BACKUP_DIR/dashboard-uids.txt"
        
        echo "✅ Dashboard export completed"
    else
        echo "⚠️  No dashboards found or API access failed"
    fi
    
    # Backup method 2: Copy Grafana data directory
    echo "Backing up Grafana data directory..."
    
    if podman exec grafana test -d /var/lib/grafana; then
        # Create a tar backup of the grafana data
        podman exec grafana tar -czf /tmp/grafana-data.tar.gz -C /var/lib/grafana .
        podman cp grafana:/tmp/grafana-data.tar.gz "$BACKUP_DIR/grafana-data.tar.gz"
        podman exec grafana rm /tmp/grafana-data.tar.gz
        echo "✅ Data directory backup completed"
    else
        echo "❌ Could not access Grafana data directory"
    fi
    
    # Backup datasources
    echo "Backing up datasources..."
    curl -s -u admin:admin123 "http://localhost:3000/api/datasources" > "$BACKUP_DIR/datasources.json" 2>/dev/null
    
    # Backup users and organizations
    echo "Backing up users and orgs..."
    curl -s -u admin:admin123 "http://localhost:3000/api/users" > "$BACKUP_DIR/users.json" 2>/dev/null
    curl -s -u admin:admin123 "http://localhost:3000/api/orgs" > "$BACKUP_DIR/orgs.json" 2>/dev/null
    
    # Create restore script
    cat > "$BACKUP_DIR/restore-dashboards.sh" << 'EOF'
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
EOF
    
    chmod +x "$BACKUP_DIR/restore-dashboards.sh"
    
    echo ""
    echo "✅ Backup completed: $BACKUP_DIR"
    echo ""
    echo "Backup contains:"
    ls -la "$BACKUP_DIR/"
    
    echo ""
    echo "To restore after redeploy:"
    echo "1. Run your monitoring setup"
    echo "2. Wait for Grafana to be ready"
    echo "3. cd $BACKUP_DIR && ./restore-dashboards.sh"
}

restore_from_data() {
    if [ -z "$1" ]; then
        echo "Usage: $0 restore-data <backup-directory>"
        exit 1
    fi
    
    RESTORE_DIR="$1"
    
    if [ ! -d "$RESTORE_DIR" ]; then
        echo "❌ Backup directory not found: $RESTORE_DIR"
        exit 1
    fi
    
    echo "=== Restoring Grafana from data backup ==="
    
    # Stop Grafana
    systemctl --user stop grafana.service 2>/dev/null
    podman stop grafana 2>/dev/null
    
    # Restore data directory if backup exists
    if [ -f "$RESTORE_DIR/grafana-data.tar.gz" ]; then
        echo "Restoring Grafana data directory..."
        
        # Remove existing volume
        podman volume rm grafana-data 2>/dev/null
        podman volume create grafana-data
        
        # Restore data
        podman run --rm -v grafana-data:/restore -v "$(realpath $RESTORE_DIR):/backup" \
        alpine:latest tar -xzf /backup/grafana-data.tar.gz -C /restore
        
        echo "✅ Data directory restored"
    fi
    
    # Start Grafana
    systemctl --user start grafana.service
    
    echo "✅ Grafana restored and restarted"
}

case "${1:-backup}" in
    backup)
        backup_grafana
        ;;
    restore-data)
        restore_from_data "$2"
        ;;
    *)
        echo "Usage: $0 [backup|restore-data <directory>]"
        echo "  backup      - Backup current Grafana configuration"
        echo "  restore-data - Restore from data backup"
        exit 1
        ;;
esac