# Azure PostgreSQL Flexible Server Backup Summary

**Date:** 2025-06-13 01:57:18 -0700
**Backup Directory:** backup/database_backup_1749805036
**Database:** chatwoot_production
**Server:** chatwoot-db-fresh
**Resource Group:** chatwoot-rg
**Status:** 
**Duration:** 1.06 seconds
**Azure Backup Name:** manual-backup-20250613_015716

## Files Created:
- backup/database_backup_1749805036/backup_log_20250613_015716.txt
- backup/database_backup_1749805036/backup_info.json
- backup/database_backup_1749805036/backup_summary.md

## Azure CLI Commands Used:
```bash
# List existing backups
az postgres flexible-server backup list --resource-group chatwoot-rg --server-name chatwoot-db-fresh

# Create new backup
az postgres flexible-server backup create --resource-group chatwoot-rg --server-name chatwoot-db-fresh --backup-name manual-backup-20250613_015716

# Show backup details
az postgres flexible-server backup show --resource-group chatwoot-rg --server-name chatwoot-db-fresh --backup-name manual-backup-20250613_015716
```

## Restore Options:
1. **Point-in-time restore:** Create new server from backup
2. **Azure Portal:** Use backup/restore feature
3. **Azure CLI:** Use restore commands

## Important Notes:
- This backup is stored in Azure and managed by Azure Database for PostgreSQL
- The backup includes the entire server, not just the specific database
- Retention period depends on your Azure backup policy
- For database-specific exports, use pg_dump with proper network access
