# KrakenD Localhost Backend Misconfiguration

**Date:** 2025-01-04  
**Time:** 19:30 UTC  
**Severity:** CRITICAL - Blocks all Twilio webhook processing  

## Symptoms
- Twilio text messages not appearing in Chatwoot inbox
- KrakenD gateway receives webhooks but doesn't create messages
- Backend logs show no webhook activity
- Manual webhook tests through KrakenD fail silently

## Root Cause Analysis

### Problem Identified
In `krakend.json`, both Twilio webhook endpoints were configured with incorrect backend hosts:

**BEFORE (Broken Configuration):**
```json
"host": [
  "http://localhost:3000"
]
```

**AFTER (Fixed Configuration):**
```json
"host": [
  "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
]
```

### Affected Endpoints
1. `/twilio/callback` - SMS/MMS webhook processing
2. `/twilio/delivery_status` - Delivery status updates

### Impact
- All Twilio webhooks routed to non-existent localhost:3000
- Zero webhook processing despite successful KrakenD routing
- Messages lost in transit between KrakenD and backend

## Verification Steps

### Step 1: Identify Misconfiguration
```bash
# Check KrakenD configuration
grep -A 10 "twilio/callback" krakend.json
grep -A 10 "twilio/delivery_status" krakend.json
```

**Expected Result:** Should show Azure backend URL, not localhost

### Step 2: Verify Backend Connectivity
```bash
# Test backend directly
curl -X POST https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/twilio/callback \
  -H "X-Krakend: test" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "From=%2B14353397687&To=%2B19795412927&Body=Test"
```

**Expected Result:** HTTP 204 with message created in database

### Step 3: Test Through KrakenD Gateway
```bash
# Test through corrected KrakenD
curl -X POST http://chatwoot-security-gateway.eastus.azurecontainer.io:8080/twilio/callback \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "User-Agent: TwilioProxy/1.1" \
  -d "From=%2B14353397687&To=%2B19795412927&Body=Test%20via%20KrakenD"
```

**Expected Result:** HTTP 204 with message visible in Chatwoot inbox

## Resolution Applied

### Files Modified
- `krakend.json` - Updated backend hosts for Twilio webhook endpoints

### Changes Made
1. **Line 219:** Changed `/twilio/callback` backend from localhost to Azure URL
2. **Line 257:** Changed `/twilio/delivery_status` backend from localhost to Azure URL

## Post-Resolution Actions Required

### 1. Redeploy KrakenD Container
```bash
# Build new KrakenD image with corrected configuration
docker build -f Dockerfile.krakend -t voicelinkcrm.azurecr.io/chatwoot-krakend-security:v2 .

# Push to registry
docker push voicelinkcrm.azurecr.io/chatwoot-krakend-security:v2

# Update Azure Container Instance
az container restart --name chatwoot-krakend-security --resource-group YOUR_RESOURCE_GROUP
```

### 2. Verify Webhook URL Configuration
Ensure Twilio Console webhook URL is set to:
```
http://chatwoot-security-gateway.eastus.azurecontainer.io:8080/twilio/callback
```

### 3. Test End-to-End Functionality
Send test SMS to configured Twilio number and verify message appears in Chatwoot.

## Prevention Measures

### Configuration Validation Checklist
- [ ] All backend hosts point to correct Azure endpoints
- [ ] No localhost references in production configuration
- [ ] Webhook endpoints properly configured
- [ ] Security headers correctly set

### Monitoring Setup
- [ ] Monitor KrakenD logs for backend connection errors
- [ ] Track webhook success/failure rates
- [ ] Alert on webhook processing failures

## Status
✅ **RESOLVED** - KrakenD configuration corrected to use proper Azure backend URLs  
📋 **PENDING** - Container redeploy required to apply changes  
🔍 **TESTING** - End-to-end webhook verification needed 