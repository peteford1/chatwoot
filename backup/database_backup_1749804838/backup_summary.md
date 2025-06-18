# Database Backup Summary
Date: 2025-06-13 01:54:01 -0700
Backup Directory: backup/database_backup_1749804838
Database: chatwoot_production
Host: chatwoot-db-fresh.postgres.database.azure.com
Status: completed_but_file_missing
Duration: 3.09 seconds


## Files Created:
- backup/database_backup_1749804838/chatwoot_production_20250613_015358.sql
- backup/database_backup_1749804838/backup_log_20250613_015358.txt
- backup/database_backup_1749804838/backup_info.json
- backup/database_backup_1749804838/backup_summary.md

## Restore Command:
psql --host=chatwoot-db-fresh.postgres.database.azure.com --port=5432 --username=chatwoot_prod --dbname=chatwoot_production < backup/database_backup_1749804838/chatwoot_production_20250613_015358.sql
