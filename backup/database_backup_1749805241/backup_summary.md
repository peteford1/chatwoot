# Azure PostgreSQL Database Backup Summary

**Date:** 2025-06-13 02:00:46 -0700
**Backup Directory:** backup/database_backup_1749805241
**Database:** chatwoot_production
**Server:** chatwoot-db-fresh
**Resource Group:** SM-Test
**Status:** success
**Duration:** 3.03 seconds
**Azure Backup Name:** manual-backup-20250613_020041

## Files Created:
- backup/database_backup_1749805241/backup_log_20250613_020041.txt
- backup/database_backup_1749805241/backup_info.json
- backup/database_backup_1749805241/backup_summary.md

## Azure CLI Commands Used:
```bash
# List existing backups
az postgres flexible-server backup list -g SM-Test -n chatwoot-db-fresh

# Create new backup
az postgres flexible-server backup create -g SM-Test -n chatwoot-db-fresh --backup-name manual-backup-20250613_020041

# Show backup details
az postgres flexible-server backup show -g SM-Test -n chatwoot-db-fresh --backup-name manual-backup-20250613_020041
```

## Restore Command:
```bash
az postgres flexible-server restore \
  --resource-group SM-Test \
  --name NEW_SERVER_NAME \
  --source-server chatwoot-db-fresh \
  --backup-name manual-backup-20250613_020041
```

## Important Notes:
- ✅ Backup stored securely in Azure
- 🔄 Includes entire PostgreSQL server
- 📅 Retention based on Azure backup policy
- 🔐 Managed by Azure Database for PostgreSQL
- 🚀 Can be restored to new server instance

## Database Connection Details:
- **Host:** chatwoot-db-fresh.postgres.database.azure.com
- **Database:** chatwoot_production
- **Port:** 5432
