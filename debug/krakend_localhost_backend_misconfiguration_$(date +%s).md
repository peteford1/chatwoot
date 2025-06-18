# KrakenD Backend Misconfiguration - Local Development Issue

**Issue Date:** 2025-06-06  
**Status:** 🔍 IDENTIFIED  
**Severity:** HIGH - Blocks all webhook processing in local development  

## Problem Summary
KrakenD gateway is configured to forward webhook requests to Azure backend instead of local Rails server, causing webhook processing to fail in local development environment.

## Symptoms
- ✅ KrakenD receives webhook requests (HTTP 204 in gateway logs)
- ❌ Local Rails server never receives requests (no logs)
- ❌ No conversations or messages created
- ❌ Sidekiq jobs never executed

## Root Cause Analysis

### Current KrakenD Configuration
**File:** `krakend.json` lines 406-434

```json
{
  "endpoint": "/twilio/callback",
  "method": "POST",
  "backend": [
    {
      "url_pattern": "/twilio/callback",
      "method": "POST",
      "host": [
        "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
      ]
    }
  ]
}
```

### Issue
- **Expected:** `http://localhost:3000` (local Rails server)
- **Actual:** `https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io` (Azure backend)

## Services Status
- ✅ **KrakenD Gateway:** Running on port 8088
- ✅ **Rails Server:** Running on port 3000  
- ✅ **Sidekiq:** Running and ready to process jobs
- ❌ **Backend Routing:** Misconfigured to Azure instead of localhost

## Resolution Required
1. Update KrakenD configuration to point to `http://localhost:3000`
2. Restart KrakenD gateway
3. Test webhook processing

## Test Commands
```bash
# Current (failing) - goes to Azure
curl -X POST http://localhost:8088/twilio/callback -H "Content-Type: application/x-www-form-urlencoded" -d "From=%2B14353397687&To=%2B19795412927&Body=Test&AccountSid=AC62c0b1130dca59524440547d60dd10a9&MessageSid=SM123&SmsSid=SM123&ApiVersion=2010-04-01"

# Expected (after fix) - should go to localhost:3000
curl -X POST http://localhost:3000/twilio/callback -H "Content-Type: application/x-www-form-urlencoded" -d "From=%2B14353397687&To=%2B19795412927&Body=Test&AccountSid=AC62c0b1130dca59524440547d60dd10a9&MessageSid=SM123&SmsSid=SM123&ApiVersion=2010-04-01"
```

## Next Steps
1. Backup current krakend.json
2. Update backend host configuration
3. Restart KrakenD
4. Verify webhook processing works end-to-end 