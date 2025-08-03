# 🗄️ Grafana Backups

This directory contains automated backups of Grafana dashboards, datasources, and configuration from our webserver environments.

## 📁 Directory Structure

```
grafana-backups/
├── grafana-backup-webserver-prod-YYYYMMDD-HHMMSS/
│   ├── backup-metadata.json          # Backup information and timestamps
│   ├── dashboard-uids.txt             # List of dashboard UIDs
│   ├── dashboard-[UID].json          # Individual dashboard exports
│   ├── datasources.json              # Grafana datasources configuration
│   ├── org-preferences.json          # Organization preferences
│   └── restore.sh                    # Automated restore script
└── grafana-backup-webserver-staging-YYYYMMDD-HHMMSS/
    └── (same structure as above)
```

## 🚀 How Backups Are Created

Backups are automatically created using the **Grafana Backup & Restore** GitHub Actions workflow:

1. **Manual Trigger**: Go to Actions → "🗄️ Grafana Backup & Restore"
2. **Select Operation**: Choose "backup"
3. **Choose Environment**: `webserver-prod` or `webserver-staging`
4. **Automated Process**:
   - Connects to target environment via Tailscale
   - Exports all dashboards via Grafana API
   - Downloads datasources and preferences
   - Creates restore script
   - Commits backup to this repository

## 🔄 How to Restore Backups

### Via GitHub Actions (Recommended)

1. **Go to Actions** → "🗄️ Grafana Backup & Restore"
2. **Select Operation**: Choose "restore"
3. **Choose Target**: Environment to restore to
4. **Select Source**:
   - `latest-prod`: Most recent production backup
   - `latest-staging`: Most recent staging backup
   - `select-specific`: Choose exact backup by name

### Cross-Environment Restore Examples

- **Prod → Staging**: Copy production dashboards to staging for testing
- **Staging → Prod**: Promote tested dashboards to production
- **Rollback**: Restore from previous backup after issues

### Manual Restore (SSH)

```bash
# Copy backup to target environment
scp -r grafana-backup-webserver-prod-20240101-120000/ opc@webserver-staging:~/

# Execute restore script
ssh opc@webserver-staging "cd ~/grafana-backup-webserver-prod-20240101-120000 && ./restore.sh"
```

## 📊 Backup Contents

Each backup contains:

- **📈 Dashboards**: Complete dashboard definitions with panels, queries, and layouts
- **🔗 Datasources**: Prometheus and other datasource configurations
- **⚙️ Preferences**: Organization settings and preferences
- **📋 Metadata**: Backup timestamp, source environment, dashboard count
- **🔄 Restore Script**: Automated restoration tool

## 🛡️ Security Notes

- **No Passwords**: User passwords and auth tokens are NOT backed up for security
- **Default Credentials**: After restore, use `admin/admin123` to access Grafana
- **API Keys**: Any API keys in datasources will need to be reconfigured
- **Change Password**: Always change admin password after restore

## 📅 Backup Strategy

### Recommended Schedule

- **Before Major Changes**: Always backup before infrastructure updates
- **Weekly**: Regular production backups for disaster recovery
- **Before Releases**: Backup staging before promoting to production

### Retention

- Backups are stored indefinitely in source control
- Consider archiving very old backups (>6 months) if repository size becomes an issue
- Critical backups can be tagged for easy identification

## 🔍 Backup Verification

Each backup includes metadata for verification:

```json
{
  "backup_date": "2024-01-01T12:00:00Z",
  "source_host": "webserver-prod",
  "grafana_version": "10.2.0",
  "dashboard_count": 5,
  "backup_type": "api_export"
}
```

## 🚨 Troubleshooting

### Common Issues

1. **No Dashboards After Restore**
   - Check Grafana logs: `podman logs grafana`
   - Verify datasources are working
   - Check dashboard JSON format

2. **Datasource Errors**
   - Verify Prometheus is running
   - Check network connectivity between pods
   - Reconfigure datasource URLs if needed

3. **Permission Errors**
   - Ensure monitoring-pod is running
   - Verify Grafana admin credentials
   - Check pod networking configuration

### Debug Commands

```bash
# Check Grafana health
curl -s http://localhost:3000/api/health

# List current dashboards
curl -s -u admin:admin123 "http://localhost:3000/api/search?type=dash-db" | jq

# Check datasources
curl -s -u admin:admin123 "http://localhost:3000/api/datasources" | jq

# Monitor restore process
podman logs grafana --tail 50
```

## 💡 Best Practices

1. **Test Restores**: Regularly test restore process on staging
2. **Document Changes**: Add notes to significant dashboard modifications
3. **Backup Before Updates**: Always backup before infrastructure changes
4. **Cross-Environment Testing**: Use staging to test dashboard changes
5. **Monitor Storage**: Keep an eye on repository size as backups accumulate

## 🤝 Contributing

When making dashboard changes:

1. **Test in Staging**: Make changes in staging environment first
2. **Backup Current State**: Create backup before major modifications
3. **Document Changes**: Update dashboard descriptions and commit messages
4. **Promote to Production**: Use backup/restore to move tested changes

---

**📞 Need Help?** Check the main repository README or GitHub Actions workflow logs for detailed troubleshooting information.