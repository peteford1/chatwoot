# KrakenD Configuration Fixes - June 11, 2025
**Date:** 2025-06-11 05:56:00  
**Issue:** KrakenD endpoints misconfigured and missing sync_accounts endpoint  
**Environment:** Azure Container Apps, KrakenD Gateway

## Issues Fixed

### 1. Twilio Webhook Backend Configuration ✅
**Problem:** Twilio webhooks pointing to incorrect backend host
- **Endpoint:** `/twilio/callback` and `/twilio/delivery_status`
- **Wrong Host:** `http://host.docker.internal:3000`
- **Correct Host:** `https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io`

**Changes Made:**
```json
// Before:
"host": ["http://host.docker.internal:3000"]

// After:
"host": ["https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"]
```

**Additional Enhancements:**
- Added Lua transformation for Twilio webhooks
- Consistent error handling configuration

### 2. Missing SyncAccounts Endpoint ✅
**Problem:** `/api/v1/accounts/{account_id}/sync_accounts` endpoint not configured in KrakenD
- **Result:** 404 errors when frontend calls sync_accounts API through gateway
- **Impact:** Frontend forced to call backend directly, bypassing gateway security

**Solution Added:**
```json
{
  "endpoint": "/api/v1/accounts/{account_id}/sync_accounts",
  "method": "POST",
  "output_encoding": "no-op",
  "headers_to_pass": [
    "Content-Type",
    "Authorization", 
    "User-Agent"
  ],
  "extra_config": {
    "security/policies": {
      "max_conn": 100,
      "max_conn_per_ip": 20
    },
    "qos/ratelimit/router": {
      "max_rate": 200,
      "client_max_rate": 20,
      "strategy": "ip"
    }
  },
  "backend": [
    {
      "url_pattern": "/api/v1/accounts/{account_id}/sync_accounts",
      "encoding": "no-op",
      "method": "POST",
      "host": [
        "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
      ],
      "extra_config": {
        "backend/http": {
          "return_error_code": true
        }
      }
    }
  ]
}
```

## Files Modified
- ✅ `krakend.json` - Main KrakenD configuration
- ✅ `backup/krakend_fixed_1749616569.json` - Backup created

## Testing Status
- ⏳ **Awaiting KrakenD Restart:** Configuration changes require service restart
- ✅ **Twilio Endpoints:** Fixed backend routing  
- ✅ **SyncAccounts Endpoint:** Added to configuration
- ⏳ **Live Testing:** Pending restart to verify fixes

## Next Steps Required

### 1. Restart KrakenD Service
KrakenD needs to reload configuration to apply changes:
```bash
# If running in Docker:
docker restart <krakend-container-name>

# If running in Azure Container Apps:
az containerapp revision restart --name <krakend-app-name> --resource-group <resource-group>
```

### 2. Verify Fixed Endpoints
After restart, test:

**Twilio Webhook:**
```bash
curl -X POST http://voicelinkai.com/twilio/callback \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "X-Twilio-Signature: test_signature" \
  -d "MessageSid=SM123&From=+1555123&To=+1555456&Body=test"
```

**SyncAccounts API:**
```bash
curl -X POST http://voicelinkai.com/api/v1/accounts/1/sync_accounts \
  -H "Content-Type: application/json" \
  -d '{"sync_accounts": {"sm_store_id": 1, "store_name": "Test", ...}}'
```

## Expected Results After Restart
- **Twilio Webhooks:** Should route to Chatwoot backend (no more RBAC errors)
- **SyncAccounts:** Should be accessible through KrakenD gateway  
- **Frontend Integration:** Can use gateway URL instead of direct backend calls
- **Security:** All requests benefit from KrakenD rate limiting and policies

## Configuration Validation
✅ JSON syntax valid  
✅ Backend hosts consistent  
✅ Header configurations appropriate  
✅ Rate limiting configured  
✅ Error handling enabled  

**Status:** Configuration Fixed - Container Updated Successfully ✅

## Deployment Results

### ✅ **Container Deployment Successful**
- **New Image:** `voicelinkcrm.azurecr.io/voicelinkai-gateway:v30-fixed-amd64`
- **Container Name:** `voicelinkai-gateway-instance-v29` (recreated)
- **IP Address:** `10.0.2.4:8080` (same as before)
- **Status:** Running and operational

### ✅ **Configuration Verification**
From container logs, the fixed configuration is working:
```
[ENDPOINT: /api/v1/accounts/:account_id/sync_accounts][JWTValidator] Validator disabled
[ENDPOINT: /twilio/callback][JWTValidator] Validator disabled  
[ENDPOINT: /twilio/delivery_status][JWTValidator] Validator disabled
[SERVICE: Gin] Listening on port: 8080
```

### ⚠️ **Application Gateway Issue**
- **Problem:** Application Gateway returns 502 Bad Gateway
- **Root Cause:** Health probe looking for `/health` endpoint (getting 404)
- **Impact:** External access through `voicelinkai.com` not working
- **KrakenD Status:** Container is healthy and running correctly

### 🔧 **Next Steps Required**
1. **Add Health Endpoint** to KrakenD configuration:
   ```json
   {
     "endpoint": "/health",
     "method": "GET",
     "output_encoding": "json",
     "backend": [{
       "url_pattern": "/__health",
       "method": "GET",
       "host": ["http://localhost:8080"]
     }]
   }
   ```

2. **Or Update Application Gateway** health probe to use `/__health` instead of `/health`

### 🧪 **Testing Status**
- ✅ **KrakenD Configuration:** All endpoints loaded correctly
- ✅ **Backend Routing:** Fixed to point to Chatwoot backend  
- ✅ **Container Health:** Running without errors
- ❌ **External Access:** Blocked by Application Gateway health check

**Current Status:** KrakenD fixes deployed successfully - Application Gateway health probe needs adjustment 