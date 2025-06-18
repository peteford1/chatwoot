# KrakenD Static Endpoint JSON Parsing Errors - Resolution

**Date:** 2025-06-05  
**Issue:** `invalid character '<' looking for beginning of value` errors in KrakenD logs

## Problem Identified
When configuring static endpoints in KrakenD, even with `"strategy": "always"`, KrakenD still attempts to call the configured backend and logs errors when the backend returns HTML instead of JSON.

### Error Message:
```
2025/06/05 01:44:30 KRAKEND ERROR: [ENDPOINT: /api] invalid character '<' looking for beginning of value
[GIN] 2025/06/05 - 01:44:30 | 200 |  791.809834ms |    192.168.65.1 | GET      "/api"
Error #01: invalid character '<' looking for beginning of value
```

## Root Cause
- KrakenD requires at least one backend to be defined for each endpoint
- Even with static responses using `"strategy": "always"`, KrakenD still attempts to call backends
- When backends return HTML (like httpbin.org), JSON parsing fails causing logged errors
- The static response still works correctly, but errors appear in logs

## Solutions Tested

### ❌ Option 1: Remove Backend (Failed)
```json
{
  "endpoint": "/api",
  "extra_config": {
    "proxy": {
      "static": {"strategy": "always"}
    }
  }
  // No backend defined
}
```
**Result:** `ignoring the 'GET /api' endpoint, since it has 0 backends defined!`

### ✅ Option 2: Use Dummy JSON Backend
```json
{
  "endpoint": "/api",
  "extra_config": {
    "proxy": {
      "static": {
        "strategy": "always"
      }
    }
  },
  "backend": [
    {
      "url_pattern": "/get",
      "host": ["https://httpbin.org"],
      "extra_config": {
        "backend/http": {
          "return_error_details": "backend_alias"
        }
      }
    }
  ]
}
```

### ✅ Option 3: Accept the Logging (Current Solution)
- Keep the static response configuration as-is
- Accept that error logs will appear but endpoints function correctly
- The 200 status code confirms the static response is being returned successfully

## Verification
- Static endpoints return correct JSON responses (200 status)
- Error logs appear but don't affect functionality
- Frontend receives expected static data

## Recommendation
For production use, consider:
1. Using dedicated health check endpoints that return proper JSON
2. Configuring log filtering to suppress these specific errors
3. Using backend that returns JSON instead of HTML for dummy calls

## Current Status
✅ **Functional**: Static endpoints work correctly despite log errors  
⚠️ **Log Noise**: Error messages appear in logs but don't affect operation 