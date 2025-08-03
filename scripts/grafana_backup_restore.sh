#!/bin/bash

echo "=== Grafana Backup and Restore Utility (Pod Architecture) ==="

HOSTNAME="${HOSTNAME:-$(hostname)}"
BACKUP_DIR="grafana-backup-${HOSTNAME}-$(date +%Y%m%d-%H%M%S)"

backup_grafana() {
    echo "=== Backing up Grafana configuration ==="
    echo "Host: $HOSTNAME"
    echo "Backup directory: $BACKUP_DIR"

    mkdir -p "$BACKUP_DIR"

    # Check if Grafana is running (pod architecture)
    echo "Checking Grafana availability..."
    if ! curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
        echo "❌ Grafana not accessible at localhost:3000"
        echo "Checking if monitoring-pod is running..."
        podman pod ps | grep monitoring-pod || echo "monitoring-pod not found"
        podman ps | grep grafana || echo "grafana container not found"
        exit 1
    fi

    echo "✅ Grafana is accessible"

    # Get Grafana version and health info
    GRAFANA_VERSION=$(curl -s -u admin:admin123 "http://localhost:3000/api/health" 2>/dev/null | jq -r '.version // "unknown"')
    echo "Grafana version: $GRAFANA_VERSION"

    # Backup method 1: Export dashboards via API
    echo "Exporting dashboards via API..."

    # Get all dashboards with proper JSON parsing
    DASHBOARDS=$(curl -s -u admin:admin123 "http://localhost:3000/api/search?type=dash-db" 2>/dev/null || echo "[]")

    if echo "$DASHBOARDS" | jq -e 'length > 0' >/dev/null 2>&1; then
        echo "$DASHBOARDS" | jq -r '.[].uid' > "$BACKUP_DIR/dashboard-uids.txt"

        echo "Found $(wc -l < "$BACKUP_DIR/dashboard-uids.txt") dashboards to backup"

        # Export each dashboard
        while read -r uid; do
            if [ -n "$uid" ] && [ "$uid" != "null" ]; then
                echo "Exporting dashboard: $uid"
                curl -s -u admin:admin123 "http://localhost:3000/api/dashboards/uid/$uid" > "$BACKUP_DIR/dashboard-$uid.json"
            fi
        done < "$BACKUP_DIR/dashboard-uids.txt"

        echo "✅ Dashboard export completed"
    else
        echo "⚠️  No dashboards found"
        touch "$BACKUP_DIR/dashboard-uids.txt"
    fi

    # Backup method 2: Copy Grafana data directory (pod architecture)
    echo "Backing up Grafana data directory from pod..."

    if podman exec grafana test -d /var/lib/grafana 2>/dev/null; then
        # Create a tar backup of the grafana data
        podman exec grafana tar -czf /tmp/grafana-data.tar.gz -C /var/lib/grafana . 2>/dev/null
        podman cp grafana:/tmp/grafana-data.tar.gz "$BACKUP_DIR/grafana-data.tar.gz" 2>/dev/null
        podman exec grafana rm /tmp/grafana-data.tar.gz 2>/dev/null
        echo "✅ Data directory backup completed"
    else
        echo "⚠️  Could not access Grafana data directory (container may not be running)"
    fi

    # Backup datasources
    echo "Backing up datasources..."
    curl -s -u admin:admin123 "http://localhost:3000/api/datasources" > "$BACKUP_DIR/datasources.json" 2>/dev/null || echo "[]" > "$BACKUP_DIR/datasources.json"

    # Backup organization preferences
    echo "Backing up organization preferences..."
    curl -s -u admin:admin123 "http://localhost:3000/api/org/preferences" > "$BACKUP_DIR/org-preferences.json" 2>/dev/null || echo "{}" > "$BACKUP_DIR/org-preferences.json"

    # Create backup metadata
    cat > "$BACKUP_DIR/backup-metadata.json" << METADATA_EOF
{
  "backup_date": "$(date -Iseconds)",
  "source_host": "$HOSTNAME",
  "grafana_version": "$GRAFANA_VERSION",
  "dashboard_count": $(wc -l < "$BACKUP_DIR/dashboard-uids.txt"),
  "backup_type": "api_export",
  "pod_architecture": true,
  "backup_tool_version": "2.0"
}
METADATA_EOF

    # Skip users and orgs for security (password hashes)
    echo "⚠️  Skipping user/org backup for security (contains password hashes)"

    # Create note about excluded items
    cat > "$BACKUP_DIR/SECURITY_NOTE.txt" << 'EOF'
SECURITY NOTE:
- User accounts and password hashes were NOT backed up for security
- After restore, use default admin/admin123 credentials
- Change the admin password after restore
- Recreate any additional users manually

POD ARCHITECTURE NOTES:
- This backup was created from a pod-based Grafana deployment
- Restore requires the monitoring-pod to be running
- Data directory backup included for complete restoration
EOF

    # Create restore script for pod architecture
    cat > "$BACKUP_DIR/restore.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

echo "=== Restoring Grafana Configuration (Pod Architecture) ==="

# Check if we're in a pod environment
if ! podman pod ps | grep -q monitoring-pod; then
    echo "⚠️  monitoring-pod not found. Ensure pod architecture is running."
    echo "Available pods:"
    podman pod ps
fi

# Wait for Grafana to be ready
echo "Waiting for Grafana to be ready..."
for i in {1..60}; do
    if curl -s -u admin:admin123 http://localhost:3000/api/health >/dev/null 2>&1; then
        echo "✅ Grafana is ready"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "❌ Grafana not ready after 2 minutes"
        echo "Checking container status..."
        podman ps | grep grafana || echo "Grafana container not running"
        exit 1
    fi
    echo "Waiting... ($i/60)"
    sleep 2
done

# Restore datasources first (they're needed for dashboards)
if [ -f "datasources.json" ] && [ "$(jq length datasources.json)" -gt 0 ]; then
    echo "Restoring datasources..."
    jq -c '.[]' datasources.json | while read -r datasource; do
        DATASOURCE_NAME=$(echo "$datasource" | jq -r '.name')
        echo "Importing datasource: $DATASOURCE_NAME"

        # Try to create datasource, ignore errors if it already exists
        echo "$datasource" | curl -s -u admin:admin123 -H "Content-Type: application/json" \
          -d @- "http://localhost:3000/api/datasources" >/dev/null || true
    done
    echo "✅ Datasources restored"
else
    echo "⚠️  No datasources to restore"
fi

# Small delay to ensure datasources are ready
sleep 2

# Restore organization preferences
if [ -f "org-preferences.json" ]; then
    echo "Restoring organization preferences..."
    curl -s -u admin:admin123 -H "Content-Type: application/json" \
      -d @org-preferences.json "http://localhost:3000/api/org/preferences" >/dev/null || true
    echo "✅ Organization preferences restored"
fi

# Restore dashboards
if [ -f "dashboard-uids.txt" ] && [ -s "dashboard-uids.txt" ]; then
    echo "Restoring dashboards..."
    TOTAL_DASHBOARDS=$(wc -l < "dashboard-uids.txt")
    IMPORTED_COUNT=0

    while read -r uid; do
        if [ -n "$uid" ] && [ -f "dashboard-$uid.json" ]; then
            echo "Importing dashboard: $uid"

            DASHBOARD_JSON=$(cat "dashboard-$uid.json" | jq '.dashboard')
            if [ "$DASHBOARD_JSON" != "null" ]; then
                # Create import payload with proper structure
                echo "{\"dashboard\": $DASHBOARD_JSON, \"overwrite\": true, \"inputs\": []}" | \
                curl -s -u admin:admin123 -H "Content-Type: application/json" \
                -d @- "http://localhost:3000/api/dashboards/db" >/dev/null

                if [ $? -eq 0 ]; then
                    echo "✅ Imported: $uid"
                    IMPORTED_COUNT=$((IMPORTED_COUNT + 1))
                else
                    echo "❌ Failed to import: $uid"
                fi
            else
                echo "⚠️  Invalid dashboard JSON for: $uid"
            fi
        fi
    done < "dashboard-uids.txt"

    echo "✅ Dashboard restore completed: $IMPORTED_COUNT/$TOTAL_DASHBOARDS imported"
else
    echo "⚠️  No dashboards to restore"
fi

echo "=== Grafana Restore Completed ==="
echo "🌐 Access Grafana at: http://localhost:3000 (admin/admin123)"

# Show final status
echo ""
echo "📊 Final Status:"
curl -s -u admin:admin123 "http://localhost:3000/api/search?type=dash-db" | jq length | xargs echo "Dashboards:"
curl -s -u admin:admin123 "http://localhost:3000/api/datasources" | jq length | xargs echo "Datasources:"
EOF

    chmod +x "$BACKUP_DIR/restore.sh"

    echo ""
    echo "✅ Backup completed: $BACKUP_DIR"
    echo ""
    echo "Backup contains:"
    ls -la "$BACKUP_DIR/"

    echo ""
    echo "📋 Backup Summary:"
    cat "$BACKUP_DIR/backup-metadata.json" | jq .

    echo ""
    echo "🔄 To restore this backup:"
    echo "1. Ensure pod architecture is deployed and running"
    echo "2. Wait for monitoring-pod and Grafana to be ready"
    echo "3. cd $BACKUP_DIR && ./restore.sh"
    echo ""
    echo "🌐 Or use the GitHub Actions workflow:"
    echo "   - Go to Actions → Grafana Backup & Restore"
    echo "   - Select 'restore' operation"
    echo "   - Choose your target environment"
    echo "   - Select this backup: $BACKUP_DIR"
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

    echo "=== Restoring Grafana from data backup (Pod Architecture) ==="

    # Check if backup has metadata
    if [ -f "$RESTORE_DIR/backup-metadata.json" ]; then
        echo "📋 Backup metadata:"
        cat "$RESTORE_DIR/backup-metadata.json" | jq .
    fi

    # Stop monitoring pod
    echo "Stopping monitoring pod..."
    podman pod stop monitoring-pod 2>/dev/null || echo "monitoring-pod not running"

    # Restore data directory if backup exists
    if [ -f "$RESTORE_DIR/grafana-data.tar.gz" ]; then
        echo "Restoring Grafana data directory..."

        # Remove existing volume and recreate
        podman volume rm grafana-data 2>/dev/null || true
        podman volume create grafana-data

        # Restore data using temporary container
        podman run --rm -v grafana-data:/restore -v "$(realpath $RESTORE_DIR):/backup" \
        alpine:latest tar -xzf /backup/grafana-data.tar.gz -C /restore

        echo "✅ Data directory restored"
    else
        echo "⚠️  No data backup found, will use API restore only"
    fi

    # Restart monitoring pod
    echo "Starting monitoring pod..."
    systemctl --user restart webserver-pod.service 2>/dev/null || echo "⚠️  Could not restart via systemd"

    # Wait a moment for containers to start
    sleep 10

    # Run API restore if available
    if [ -f "$RESTORE_DIR/restore.sh" ]; then
        echo "Running API restore..."
        (cd "$RESTORE_DIR" && ./restore.sh)
    fi

    echo "✅ Grafana restored and restarted"
}

list_backups() {
    echo "📋 Available Grafana backups:"
    echo ""

    find . -maxdepth 1 -name "grafana-backup-*" -type d | sort -r | while read -r backup; do
        if [ -f "$backup/backup-metadata.json" ]; then
            echo "🗄️  $(basename "$backup")"
            cat "$backup/backup-metadata.json" | jq -r '
              "   📅 Date: " + .backup_date +
              "\n   🖥️  Source: " + .source_host +
              "\n   📊 Dashboards: " + (.dashboard_count | tostring) +
              "\n   📈 Grafana: " + .grafana_version + "\n"
            '
        else
            echo "🗄️  $(basename "$backup") (no metadata available)"
            echo ""
        fi
    done

    echo "💡 Usage:"
    echo "   $0 backup                    - Create new backup"
    echo "   $0 restore-api <backup-dir>  - Restore via API"
    echo "   $0 restore-data <backup-dir> - Full data restore"
    echo ""
    echo "📁 Note: GitHub Actions stores backups in grafana-backups/ folder"
    echo "   Use GitHub Actions workflow for automated cross-environment backups"
}

restore_api() {
    if [ -z "$1" ]; then
        echo "Usage: $0 restore-api <backup-directory>"
        exit 1
    fi

    RESTORE_DIR="$1"

    if [ ! -d "$RESTORE_DIR" ]; then
        echo "❌ Backup directory not found: $RESTORE_DIR"
        exit 1
    fi

    if [ ! -f "$RESTORE_DIR/restore.sh" ]; then
        echo "❌ Restore script not found in backup directory"
        exit 1
    fi

    echo "=== API-based Grafana Restore ==="
    (cd "$RESTORE_DIR" && ./restore.sh)
}

case "${1:-backup}" in
    backup)
        backup_grafana
        ;;
    restore-data)
        restore_from_data "$2"
        ;;
    restore-api)
        restore_api "$2"
        ;;
    list)
        list_backups
        ;;
    *)
        echo "Usage: $0 [backup|restore-data|restore-api|list] [directory]"
        echo ""
        echo "Commands:"
        echo "  backup              - Backup current Grafana configuration via API"
        echo "  restore-data <dir>  - Full restore including data volume"
        echo "  restore-api <dir>   - API-only restore (dashboards, datasources)"
        echo "  list                - List available backups"
        echo ""
        echo "Examples:"
        echo "  $0 backup"
        echo "  $0 list"
        echo "  $0 restore-api grafana-backup-webserver-prod-20240101-120000"
        echo "  $0 restore-data grafana-backup-webserver-staging-20240101-120000"
        echo ""
        echo "📁 Backup Storage:"
        echo "   Local backups: Current directory"
        echo "   GitHub backups: grafana-backups/ folder in repository"
        echo ""
        echo "🌐 For automated backup/restore, use the GitHub Actions workflow:"
        echo "   Actions → Grafana Backup & Restore → stores in grafana-backups/"
        exit 1
        ;;
esac
