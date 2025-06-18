# Health Endpoint Overwrite Issue - Resolution

**Date:** 2025-06-05  
**Issue:** Application Gateway health probe failures due to health endpoint configuration overwrite

## Problem Identified
While adding frontend endpoints (`/health` and `/api/v1/messages`) to KrakenD configuration, the static health response used by the Application Gateway health probe was accidentally overwritten.

### Original Working Configuration:
```json
{
  "endpoint": "/health",
  "method": "GET",
  "output_encoding": "json",
  "extra_config": {
    "proxy": {
      "static": {
        "data": {
          "status": "ok",
          "service": "krakend-gateway"
        },
        "strategy": "always"
      }
    }
  },
  "backend": [
    {
      "url_pattern": "/",
      "encoding": "json",
      "method": "GET",
      "host": ["https://httpbin.org"],
      "disable_host_sanitize": false
    }
  ]
}
```

### Problematic Configuration (Attempted):
```json
{
  "endpoint": "/health",
  "method": "GET", 
  "output_encoding": "json",
  "backend": [
    {
      "url_pattern": "/api",
      "encoding": "json",
      "method": "GET",
      "host": [
        "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
      ]
    }
  ]
}
```

## Symptoms
- Application Gateway health probe returning errors
- Backend showing "Unhealthy" status
- Frontend endpoints working but health monitoring broken

## Root Cause
The Application Gateway health probe is configured to check `/health` endpoint and expects a specific static response format. When this was changed to proxy to the backend `/api` endpoint, the health probe failed.

## Resolution Applied
1. **Restored Static Health Response**: Reverted `/health` endpoint to return static JSON response
2. **Kept Frontend Endpoints**: Maintained `/api`, `/api/v1/messages`, and other frontend endpoints
3. **Separated Concerns**: 
   - `/health` → Static response for Application Gateway health probe
   - `/api` → Proxy to backend for frontend system status
   - `/api/v1/messages` → Proxy to backend search endpoint

## Final Working Configuration
- Container: `voicelinkcrm.azurecr.io/voicelinkai-gateway:v23-health-fixed-amd64`
- Health Status: "Healthy" with 200 status code
- Frontend Endpoints: Available and working
- Backend Integration: Functional

## Verification Commands
```bash
# Test health endpoint (should return static response)
curl -k -s https://voicelinkai-gateway.eastus.cloudapp.azure.com/health

# Check Application Gateway health
az network application-gateway show-backend-health --resource-group SM-Test --name voicelinkai-gateway-appgw
```

## Prevention
Always preserve the static health endpoint configuration when adding new endpoints. The Application Gateway health probe requires a reliable, fast-responding endpoint that doesn't depend on external services. 