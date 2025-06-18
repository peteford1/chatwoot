# Azure Database Backup Summary
Date: 2025-06-13 01:55:51 -0700
Backup Directory: backup/database_backup_1749804949
Database: chatwoot_production
Server: chatwoot-db-fresh
Resource Group: chatwoot-rg
Status: completed_but_file_missing
Duration: 1.88 seconds


## Files Created:
- backup/database_backup_1749804949/chatwoot_production_20250613_015549.bacpac
- backup/database_backup_1749804949/backup_log_20250613_015549.txt
- backup/database_backup_1749804949/backup_info.json
- backup/database_backup_1749804949/backup_summary.md

## Azure CLI Commands Used:
az postgres db export --resource-group chatwoot-rg --server-name chatwoot-db-fresh --name chatwoot_production

## Alternative Restore Methods:
1. Azure Portal: Import/Export feature
2. pg_restore: pg_restore -h chatwoot-db-fresh.postgres.database.azure.com -U chatwoot_prod -d chatwoot_production backup/database_backup_1749804949/chatwoot_production_20250613_015549.bacpac
3. Azure CLI: az postgres db import
