# DNS Update Instructions - Route Traffic Through KrakenD Gateway

## Current Configuration ❌
```
Domain: voicelinkai.com
DNS Provider: Cloudflare
A Records: 104.21.79.119, 172.67.145.111 (Cloudflare Proxy)
Backend: Direct to Chatwoot Backend
```

## New Configuration ✅
```
Domain: voicelinkai.com  
DNS Provider: Cloudflare
CNAME Record: voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io
Target IP: 51.8.58.201 (KrakenD Gateway → Chatwoot Backend)
```

## DNS Update Steps

### Option 1: CNAME Record (Recommended)
1. **Log into Cloudflare Dashboard**
   - Go to https://dash.cloudflare.com
   - Select your domain: voicelinkai.com
   - Navigate to DNS > Records

2. **Update/Add CNAME Record**
   ```
   Type: CNAME
   Name: @ (or voicelinkai.com)
   Target: voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io
   Proxy Status: Proxied (Orange Cloud) ✅
   TTL: Auto
   ```

### Option 2: A Record (Alternative)
If CNAME doesn't work for root domain:
```
Type: A
Name: @ (or voicelinkai.com)
Value: 51.8.58.201
Proxy Status: Proxied (Orange Cloud) ✅
TTL: Auto
```

### 3. Verify the Change
After making the update, verify using:
```bash
# Wait 2-5 minutes for DNS propagation, then test:
./verify_dns_new.sh

# Or manually:
dig +short A voicelinkai.com
curl -s https://voicelinkai.com/api/v1/profile -H "access-token: test" -w "%{http_code}"
```

## Pre-Change Verification ✅

Gateway is ready and tested:

- ✅ **HTTPS Access**: `https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io`
- ✅ **SSL Certificate**: Valid Azure Container Apps certificate
- ✅ **API Routing**: Returns HTTP 401 (proper authentication flow)
- ✅ **Header Forwarding**: Fixed `input_headers` configuration deployed
- ✅ **KrakenD Version**: Updated to latest (v2.10.0)

## Post-Change Testing

After DNS propagation (2-5 minutes with Cloudflare), test:

```bash
# Test HTTPS (should work)  
curl https://voicelinkai.com/api/v1/profile -H "access-token: test" -w "%{http_code}"

# Should return: 401 (authentication required - correct behavior)

# Test with valid credentials
curl https://voicelinkai.com/api/v1/profile \
  -H "access-token: YOUR_TOKEN" \
  -H "client: YOUR_CLIENT" \
  -H "uid: YOUR_UID"
```

## Expected Results
- **Profile API**: HTTP 401 (authentication required - correct)
- **With Valid Auth**: Proper JSON response from Chatwoot
- **SSL**: Cloudflare SSL termination + Azure Container Apps SSL

## Rollback Plan
If any issues occur, you can quickly rollback in Cloudflare:
1. Go to DNS > Records
2. Change CNAME back to previous A records:
   ```
   Type: A
   Name: @
   Value: 104.21.79.119 (or previous working IP)
   ```

## Architecture After Change
```
User → voicelinkai.com (Cloudflare) → KrakenD Gateway (Azure) → Chatwoot Backend
```

This provides:
- ✅ Cloudflare CDN and DDoS protection
- ✅ KrakenD API Gateway functionality  
- ✅ Fixed header forwarding (input_headers)
- ✅ Rate limiting and security policies
- ✅ Proper authentication flow (HTTP 401 → login)
- ✅ Azure Container Apps scaling and reliability

## Important Notes
- **Cloudflare Proxy**: Keep the orange cloud enabled for DDoS protection
- **SSL Mode**: Ensure Cloudflare SSL is set to "Full (strict)" for end-to-end encryption
- **Gateway Health**: Monitor `https://voicelinkai.com/api/v1/profile` for 401 responses 