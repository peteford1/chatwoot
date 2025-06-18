# Database Backup Information
- **Source Database**: chatwoot-db.postgres.database.azure.com
- **Backup Date**: Thu Jun 12 01:36:50 PDT 2025
- **Reason**: Cleanup unused databases, keeping historical data backup
- **Contains**: Historical Account ID: 3, users, and API tokens

## Database Connection Details:
- Host: chatwoot-db.postgres.database.azure.com
- User: chatwootuser
- Database: chatwoot_production

## Azure Backup Strategy:
Since pg_dump is not available locally, the database can be restored using:

```bash
# Restore command (if needed in future):
az postgres flexible-server restore \
  --resource-group SM-Test \
  --name chatwoot-db-restored-20250612 \
  --source-server chatwoot-db \
  --restore-time "2025-06-12T08:37:15Z"
```

## Included Scripts:
- list_accounts.rb - Script that successfully queried Account ID: 3
- simple_check.rb - Database connection test script
- get_users_simple.rb - User listing script

## Historical Data Found:
- Account ID: 3 (Name: 'Default Account')
- Admin email: admin@voicelinkai.com
- Platform API Token: YkT9vdgc2UFZ2kgMhPdEaajT (expired)
- Admin API Token: 0212af10d6c85e3f692325e0 (expired)
