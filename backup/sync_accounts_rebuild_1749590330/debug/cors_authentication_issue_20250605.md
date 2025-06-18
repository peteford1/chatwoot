# CORS Authentication Issue Resolution

**Date:** January 5, 2025 01:09 AM  
**Issue:** Customer center authentication failing with "Failed to fetch" errors

## Problem Symptoms
- ❌ Azure KrakenD Gateway: Failed to fetch from `https://voicelinkai-gateway.eastus.cloudapp.azure.com/api/v1/widget/config`
- ❌ Direct Backend: Failed to fetch from `https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/widget/config`
- Error message: "Failed to fetch" indicates CORS or network connectivity issues

## Root Cause Verification Steps
1. **Check if endpoints are accessible via curl:**
   ```bash
   # Test direct backend (works)
   curl -X POST https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/widget/config \
     -H "Content-Type: application/json" \
     -d '{"website_token":"zEGFZ3658VdbbvkCTrpy8C5z"}'
   
   # Test Azure gateway (RBAC blocked)
   curl -X POST https://voicelinkai-gateway.eastus.cloudapp.azure.com/api/v1/widget/config \
     -H "Content-Type: application/json" \
     -d '{"website_token":"zEGFZ3658VdbbvkCTrpy8C5z"}'
   ```

2. **Check for running local KrakenD instances:**
   ```bash
   docker ps | grep krakend
   ```

3. **Test local KrakenD if available:**
   ```bash
   curl -s http://localhost:8088/health
   curl -X POST http://localhost:8088/api/v1/widget/config \
     -H "Content-Type: application/json" \
     -d '{"website_token":"zEGFZ3658VdbbvkCTrpy8C5z"}'
   ```

## Root Problem
- **CORS Issues**: Browser blocks cross-origin requests due to missing CORS headers
- **Azure Gateway RBAC**: Application Gateway blocks widget API endpoints with RBAC rules
- **Direct Backend**: No CORS headers configured for browser access

## Solution Applied
1. **Use Local KrakenD Gateway**: Updated `customer-center-conversations.html` to prioritize local KrakenD on port 8088
2. **Fallback Chain**: Local → Azure → Direct Backend
3. **Verified Working**: Local KrakenD successfully proxies widget config endpoint

## Configuration Changes
```javascript
const API_CONFIGS = [
    {
        name: 'Local KrakenD Gateway',
        baseUrl: 'http://localhost:8088',        // ← Primary option
        configEndpoint: '/api/v1/widget/config',
        conversationsEndpoint: '/api/v1/widget/conversations',
        messagesEndpoint: '/api/v1/widget/messages'
    },
    // ... fallback options
];
```

## Verification Steps After Fix
1. Open `customer-center-conversations.html` in browser
2. Check browser console debug logs
3. Should see: "✅ Auth token obtained" from "Local KrakenD Gateway"
4. Conversations should load successfully

## Prevention for Future
- **Local Development**: Always run local KrakenD for frontend development
- **Azure Gateway**: Configure proper CORS headers and widget API endpoints
- **Documentation**: Document CORS requirements for widget integration

## Docker Command for Local KrakenD
```bash
docker run --rm -p 8088:8080 voicelinkcrm.azurecr.io/voicelinkai-gateway:v27-static-backends-amd64
```

## Additional CORS Preflight Issue
**Problem**: Even with local KrakenD, browser was making OPTIONS preflight requests that returned 405 Method Not Allowed

**KrakenD Logs Showed**:
```
[GIN] 2025/06/05 - 08:10:59 | 405 | 1.223083ms | 192.168.65.1 | OPTIONS "/api/v1/widget/config"
```

**Root Cause**: JSON POST requests with custom headers trigger CORS preflight OPTIONS requests, but KrakenD configuration doesn't support OPTIONS method.

## Final Solution Applied
**Changed API Request Format** to avoid CORS preflight:

1. **Widget Config**: Use FormData instead of JSON
   ```javascript
   // OLD (triggers CORS preflight):
   fetch(url, {
       method: 'POST',
       headers: {'Content-Type': 'application/json'},
       body: JSON.stringify({website_token: token})
   });
   
   // NEW (no preflight):
   const formData = new FormData();
   formData.append('website_token', token);
   fetch(url, {method: 'POST', body: formData});
   ```

2. **Conversations & Messages**: Use query parameters instead of headers
   ```javascript
   // OLD (triggers CORS preflight):
   fetch(url, {headers: {'X-Auth-Token': token}});
   
   // NEW (no preflight):
   fetch(`${url}?auth_token=${token}&website_token=${websiteToken}`);
   ```

## Status
✅ **RESOLVED** - CORS-free API requests using FormData and query parameters work with local KrakenD v28-platform-api 