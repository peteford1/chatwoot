# Container Update Issue Analysis
**Created:** $(date '+%Y-%m-%d %H:%M:%S')  
**Issue:** Unable to update chatwoot-backend-test environment variables via Azure CLI

## 🚨 PROBLEM SUMMARY

### What We Tried:
1. `az containerapp update --set-env-vars` - No effect, no new revision created
2. `az containerapp update --replace-env-vars` - No effect, no new revision created  
3. `az containerapp revision copy --set-env-vars` - No effect, no new revision created
4. YAML configuration file approach - Failed due to missing container name

### Current Wrong Configuration:
```
DATABASE_URL=postgresql://chatwootuser:ChatwootSecure2025!@chatwoot-db-fresh.postgres.database.azure.com/chatwoot_production
RAILS_ENV=production
```

### Required Correct Configuration:
```
DATABASE_URL=postgresql://chatwootuser:ChatwootSecure2025!@chatwoot-db-fresh.postgres.database.azure.com/chatwoot_shared?options=-csearch_path%3Ddevelopment
RAILS_ENV=development
DATABASE_SCHEMA=development
```

## 🔍 POSSIBLE CAUSES

1. **Deployment Pipeline Override** - GitHub Actions might be overriding manual changes
2. **Resource Locks** - Azure resource might have deployment locks
3. **Permission Issues** - Service principal might lack environment update permissions
4. **Cache/Timing Issues** - Azure might be caching or not processing updates

## 🛠️ ALTERNATIVE SOLUTIONS

### Option 1: GitHub Actions Deployment
The safest approach would be to update the GitHub Actions workflow to deploy with correct environment variables.

### Option 2: Manual Container Recreation
Delete and recreate the container app with correct configuration.

### Option 3: CI/CD Configuration Fix
Update the deployment pipeline to use the environment management system.

## 📋 RECOVERY STATUS
✅ **Complete backup created**: `backup/container_deployment_1750112926/`
✅ **Rollback script ready**: Can restore to current (wrong) state if needed
✅ **Configuration documented**: All settings preserved

## 🎯 RECOMMENDATION
Since the tokens are in `chatwoot_shared` database and the test environment is hitting `chatwoot_production`, we need to either:
1. Fix the container configuration (tried, failed)
2. Create tokens in the production database temporarily
3. Use GitHub Actions to redeploy with correct configuration

## 💡 IMMEDIATE WORKAROUND
For testing purposes, we could create the required tokens in the production database that the test environment is currently using. 