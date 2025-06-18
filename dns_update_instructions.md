# DNS Update Instructions - Route Traffic Through KrakenD Gateway

## Current Configuration ❌
```
Domain: voicelinkai.com
A Record: 51.8.58.201 (Chatwoot Backend - Direct)
```

## New Configuration ✅
```
Domain: voicelinkai.com  
A Record: 172.191.60.204 (KrakenD Gateway → Chatwoot Backend)
```

## DNS Update Steps

### 1. Log into your DNS provider
- Access your domain registrar or DNS management panel
- Navigate to DNS/Zone file management for voicelinkai.com

### 2. Update the A Record
**BEFORE CHANGE:**
```
Type: A
Name: @ (or voicelinkai.com)
Value: 51.8.58.201
TTL: [current TTL]
```

**AFTER CHANGE:**
```
Type: A  
Name: @ (or voicelinkai.com)
Value: 172.191.60.204
TTL: 300 (5 minutes for faster propagation)
```

### 3. Verify the Change
After making the update, you can verify using:
```bash
# Wait 5-10 minutes for DNS propagation, then test:
nslookup voicelinkai.com

# Should return: 172.191.60.204
```

## Pre-Change Verification ✅

I've already verified that the KrakenD gateway is ready:

- ✅ **HTTP Access**: `curl http://172.191.60.204/health` → `{"service":"krakend-gateway","status":"ok"}`
- ✅ **HTTPS Access**: `curl https://172.191.60.204/health` → `{"service":"krakend-gateway","status":"ok"}`
- ✅ **SSL Certificate**: Valid and working
- ✅ **API Routing**: Successfully proxying to Chatwoot backend
- ✅ **Host Header**: Works with voicelinkai.com hostname

## Post-Change Testing

After DNS propagation (5-10 minutes), test:

```bash
# Test HTTP (should work)
curl http://voicelinkai.com/health

# Test HTTPS (should work)  
curl https://voicelinkai.com/health

# Test API endpoints (should return RBAC responses)
curl -H "Accept: application/json" https://voicelinkai.com/platform/api/v1/accounts
```

## Expected Results
- **Health Endpoint**: `{"service":"krakend-gateway","status":"ok"}`
- **Platform API**: `RBAC: access denied` (authentication required)
- **Widget API**: Working through KrakenD proxy

## Rollback Plan
If any issues occur, you can quickly rollback by changing the A record back to:
```
Value: 51.8.58.201
```

## Architecture After Change
```
User → voicelinkai.com (172.191.60.204) → KrakenD Gateway → Chatwoot Backend
```

This provides:
- ✅ API Gateway functionality
- ✅ Rate limiting and security policies  
- ✅ Request/response transformation
- ✅ Load balancing capabilities
- ✅ Centralized logging and monitoring 