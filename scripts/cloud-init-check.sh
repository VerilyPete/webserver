#!/bin/bash
# Cloud-init status checker script
# This script provides detailed information about cloud-init status and helps diagnose issues

set -e

echo "=== Cloud-init Status Check ==="
echo "Timestamp: $(date)"
echo ""

# Check if cloud-init is installed
if ! command -v cloud-init &> /dev/null; then
    echo "❌ Cloud-init is not installed"
    exit 1
fi

# Get basic status
echo "1. Basic cloud-init status:"
cloud-init status || echo "Failed to get status"

echo ""
echo "2. Detailed cloud-init status:"
cloud-init status --long || echo "Failed to get detailed status"

echo ""
echo "3. Cloud-init version:"
cloud-init --version || echo "Failed to get version"

echo ""
echo "4. Cloud-init logs (last 30 lines):"
if [ -f /var/log/cloud-init.log ]; then
    tail -30 /var/log/cloud-init.log
else
    echo "No cloud-init.log found"
fi

echo ""
echo "5. Cloud-init output logs (last 30 lines):"
if [ -f /var/log/cloud-init-output.log ]; then
    tail -30 /var/log/cloud-init-output.log
else
    echo "No cloud-init-output.log found"
fi

echo ""
echo "6. System journal entries for cloud-init (last 20):"
journalctl -u cloud-init --no-pager -n 20 2>/dev/null || echo "No cloud-init journal entries found"

echo ""
echo "7. Check for cloud-init processes:"
ps aux | grep cloud-init | grep -v grep || echo "No cloud-init processes running"

echo ""
echo "8. Check cloud-init configuration:"
if [ -f /etc/cloud/cloud.cfg ]; then
    echo "Cloud-init config exists"
    ls -la /etc/cloud/
else
    echo "No cloud-init config found"
fi

echo ""
echo "9. Check for user data:"
if [ -f /var/lib/cloud/instances/*/user-data.txt ]; then
    echo "User data found:"
    ls -la /var/lib/cloud/instances/*/user-data.txt
else
    echo "No user data found"
fi

echo ""
echo "10. Check cloud-init instance data:"
if [ -d /var/lib/cloud/instances ]; then
    echo "Instance data directory:"
    ls -la /var/lib/cloud/instances/
    for instance in /var/lib/cloud/instances/*; do
        if [ -d "$instance" ]; then
            echo "Instance: $(basename "$instance")"
            if [ -f "$instance/status.json" ]; then
                echo "Status: $(cat "$instance/status.json" | jq -r '.v1.status' 2>/dev/null || echo 'unknown')"
            fi
        fi
    done
else
    echo "No cloud-init instance data found"
fi

echo ""
echo "=== Status Summary ==="
STATUS=$(cloud-init status | grep "status:" | awk '{print $2}' || echo "unknown")
echo "Current status: $STATUS"

case $STATUS in
    "done")
        echo "✅ Cloud-init completed successfully"
        exit 0
        ;;
    "running")
        echo "⚠️ Cloud-init is still running"
        exit 0
        ;;
    "error")
        echo "❌ Cloud-init reported error status"
        exit 1
        ;;
    "disabled")
        echo "⚠️ Cloud-init is disabled"
        exit 0
        ;;
    *)
        echo "⚠️ Unknown cloud-init status: $STATUS"
        exit 0
        ;;
esac 