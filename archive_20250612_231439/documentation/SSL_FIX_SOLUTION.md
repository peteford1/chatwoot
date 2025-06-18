# 🔧 SSL Handshake Error - IMMEDIATE SOLUTION

## 🚨 Problem Summary
Your frontend is getting **cURL error 35: SSL routines::unexpected eof while reading** when trying to connect to `https://voicelinkai.com`.

## ✅ IMMEDIATE FIX - Use Direct URLs

**Instead of using `https://voicelinkai.com`, use these working URLs:**

### 🌐 For Frontend API Calls:
```javascript
// Replace this:
const API_BASE = 'https://voicelinkai.com';

// With this:
const API_BASE = 'https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io';
```

### 🔗 Working URLs:
- **Gateway (KrakenD)**: `https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io`
- **Direct Backend**: `https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io`
- **SuperAdmin Panel**: `https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin/sign_in`

## 🔍 Root Cause
The KrakenD gateway is configured with SSL certificates that don't exist:
```json
"tls": {
  "public_key": "/etc/krakend/voicelinkai.com.crt",
  "private_key": "/etc/krakend/voicelinkai.com.key"
}
```

This causes SSL handshake failures when accessing `voicelinkai.com`.

## 🛠️ PERMANENT FIX (To Do Later)

### Step 1: Fix Registry Authentication
```bash
# Grant container app access to registry
az containerapp identity assign --name voicelinkai-gateway-instance-v32 --resource-group SM-Test --system-assigned
az role assignment create --assignee <PRINCIPAL_ID> --role AcrPull --scope <REGISTRY_SCOPE>
```

### Step 2: Deploy SSL-Free Configuration
```bash
# Update with the SSL-free image we built
az containerapp update \
  --name voicelinkai-gateway-instance-v32 \
  --resource-group SM-Test \
  --image chatwootregistry95290.azurecr.io/krakend-no-ssl:latest
```

### Step 3: Configure Custom Domain (Optional)
```bash
# Add custom domain with proper SSL
az containerapp hostname add \
  --name voicelinkai-gateway-instance-v32 \
  --resource-group SM-Test \
  --hostname voicelinkai.com
```

## 🧪 Testing Commands

### Test Gateway Health:
```bash
curl -I https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io/health
```

### Test Widget API:
```bash
curl -X POST https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/widget/config \
  -H "Content-Type: application/json" \
  -d '{"website_token":"test"}'
```

### Test Backend Direct:
```bash
curl -I https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/app
```

## 📋 Action Items

### ✅ IMMEDIATE (Do Now):
1. **Update your frontend code** to use the direct Azure Container Apps URLs
2. **Test all API endpoints** with the new URLs
3. **Verify functionality** works without SSL errors

### 🔄 LATER (When Time Permits):
1. Fix Azure Container Registry authentication
2. Deploy SSL-free KrakenD configuration  
3. Set up proper custom domain with SSL certificates
4. Update DNS to point to the correct endpoints

## 🎯 Expected Results
- ✅ No more SSL handshake errors
- ✅ Frontend can connect to Chatwoot APIs
- ✅ All functionality working through direct URLs
- ⏳ Custom domain fix pending registry authentication

## 📞 Support
If you need help implementing these changes in your frontend code, let me know which files need to be updated! 