# Database and Token Migration Plan

## 📊 **Database Changes Detected**

### **Old Database:**
- **Name**: `chatwoot-db`
- **FQDN**: `chatwoot-db.postgres.database.azure.com`
- **Status**: ❌ Old/Deprecated

### **New Database:**
- **Name**: `chatwoot-db-new`
- **FQDN**: `chatwoot-db-new.postgres.database.azure.com`
- **Created**: 2025-06-11T09:07:40.594331+00:00
- **Status**: ✅ Active
- **Credentials**: `chatwootuser` / `chatwoot123`

## 🔧 **Files Requiring Database URL Updates**

### **Critical Production Files:**
1. `redis-sidecar.yaml` - Line 26
2. `working-config.yaml` - Line 151 ✅ (Already updated)
3. `update_storeadmin_password_direct.rb` - Line 10
4. `azure-deployment-notes.md` - Line 39

### **Scripts Already Updated:**
- `simple_check.rb` ✅
- `get_users_simple.rb` ✅

## 🔑 **Hardcoded Tokens Requiring Environment Variable Migration**

### **Platform Token: `YkT9vdgc2UFZ2kgMhPdEaajT`**
**Files to update:**
1. `test_admin_token.rb` - Line 10
2. `simple_list_users.rb` - Line 10
3. `test_api_tokens.rb` - Line 10
4. `create_account22_twilio_inbox_fixed.rb` - Line 20
5. `custom/scripts/account_management/cleanup_duplicate_accounts_auto.rb` - Line 18
6. `custom/scripts/account_management/cleanup_duplicate_accounts.rb` - Line 18
7. `create_twilio_sms_inbox_example.rb` - Line 127
8. `test_token_profile.rb` - Line 10
9. `debug_api_connection.rb` - Line 16
10. `test_direct_api.rb` - Line 20

### **Admin Token: `0212af10d6c85e3f692325e0`**
**Files to update:**
1. `test_admin_token.rb` - Line 9
2. `create_website_inbox.rb` - Line 11

## 📋 **Environment Variables to Define**

```bash
# Database Configuration
export DATABASE_HOST="chatwoot-db-new.postgres.database.azure.com"
export DATABASE_USER="chatwootuser"
export DATABASE_PASSWORD="chatwoot123"
export DATABASE_NAME="chatwoot_production"
export DATABASE_URL="postgresql://chatwootuser:chatwoot123@chatwoot-db-new.postgres.database.azure.com:5432/chatwoot_production"

# API Tokens (TO BE UPDATED WHEN NEW TOKENS ARE GENERATED)
export CHATWOOT_PLATFORM_TOKEN="YkT9vdgc2UFZ2kgMhPdEaajT"  # Replace with new token
export CHATWOOT_ADMIN_TOKEN="0212af10d6c85e3f692325e0"     # Replace with new token

# Application URLs
export FRONTEND_URL="https://voicelinkai.com"
export BACKEND_URL="https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
export GATEWAY_URL="https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
```

## 🚀 **Migration Steps**

### **Phase 1: Database URL Updates (Immediate)**
1. Update remaining files with old database references
2. Test database connectivity with new URL
3. Update Azure Container Apps environment variables

### **Phase 2: Token Environment Variables (When new tokens available)**
1. Generate new valid API tokens through Chatwoot admin
2. Update all scripts to use environment variables
3. Set environment variables in deployment configurations
4. Test API connectivity with new tokens

### **Phase 3: Validation**
1. Test all scripts with environment variables
2. Verify database connections
3. Validate API token functionality
4. Update documentation

## ⚠️ **Notes**
- Current API tokens appear to be invalid/expired
- Database migration completed successfully
- Some files already use environment variables (good practice)
- Need to generate fresh API tokens before Phase 2 