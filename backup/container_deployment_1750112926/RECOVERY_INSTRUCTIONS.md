# Container Deployment Recovery Instructions
**Backup Created:** $(date '+%Y-%m-%d %H:%M:%S')  
**Container:** chatwoot-backend-test  
**Resource Group:** SM-Test  

## 🚨 RECOVERY INFORMATION

### Current Configuration Before Changes
- **Image:** chatwoot/chatwoot:latest
- **Database:** chatwoot_production (WRONG - this is what we're fixing)
- **Rails Env:** production
- **Revision:** chatwoot-backend-test--0000053

### 📁 Backup Files
- `current_container_config.json` - Complete container configuration
- `current_env_vars.json` - All environment variables
- `current_image.txt` - Container image reference
- `rollback_script.sh` - Automated rollback script

## 🔄 ROLLBACK PROCEDURE (if needed)

### Option 1: Automated Rollback
```bash
# Run the rollback script
cd backup/container_deployment_1750112926
chmod +x rollback_script.sh
./rollback_script.sh
```

### Option 2: Manual Rollback
```bash
# Revert to previous revision
az containerapp revision set-mode --name chatwoot-backend-test --resource-group SM-Test --mode single --revision-name chatwoot-backend-test--0000053

# Or restore specific environment variables
az containerapp update --name chatwoot-backend-test --resource-group SM-Test \
  --set-env-vars DATABASE_URL="postgresql://chatwootuser:ChatwootSecure2025!@chatwoot-db-fresh.postgres.database.azure.com/chatwoot_production"
```

### Option 3: Complete Restore from Backup
```bash
# This would require recreating the container app from the JSON backup
# (More complex, only if other options fail)
```

## 🎯 WHAT WE'RE CHANGING

### FROM (Current - Wrong):
```
DATABASE_URL=postgresql://chatwootuser:ChatwootSecure2025!@chatwoot-db-fresh.postgres.database.azure.com/chatwoot_production
RAILS_ENV=production
```

### TO (Fixed - Correct):
```
DATABASE_URL=postgresql://chatwootuser:ChatwootSecure2025!@chatwoot-db-fresh.postgres.database.azure.com/chatwoot_shared?options=-csearch_path%3Ddevelopment
RAILS_ENV=development
DATABASE_SCHEMA=development
```

## ✅ VERIFICATION STEPS

After rollback (if needed):
1. Check container status: `az containerapp show --name chatwoot-backend-test --resource-group SM-Test --query 'properties.runningStatus'`
2. Test connectivity: `curl https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/`
3. Verify tokens work: Test with known valid tokens

## 🆘 EMERGENCY CONTACTS
- Backup created by: Cursor AI Assistant
- Deployment system: Azure Container Apps
- Time sensitive: Yes (if authentication issues persist) 