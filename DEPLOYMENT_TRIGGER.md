# Deployment Trigger

**Trigger Time:** $(date '+%Y-%m-%d %H:%M:%S')  
**Purpose:** Deploy test environment with correct database configuration  
**Target:** chatwoot-backend-test using chatwoot_shared database with development schema  

## Configuration Applied

- **Environment:** development
- **Database:** chatwoot_shared
- **Schema:** development  
- **Rails Environment:** development
- **Frontend URL:** https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io

This deployment will fix the database mismatch issue where tokens exist in development database but test environment was using production database. 