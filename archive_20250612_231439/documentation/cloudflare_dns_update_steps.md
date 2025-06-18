# Cloudflare DNS Update - Step by Step Guide

## 🎯 Objective
Update `voicelinkai.com` DNS to route traffic through the new KrakenD Gateway deployed at:
`voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io`

## 📋 Pre-Update Checklist
- [x] KrakenD Gateway deployed and tested (HTTP 401 responses ✅)
- [x] Gateway FQDN: `voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io`
- [x] Gateway IP: `51.8.58.201`
- [x] SSL Certificate: Valid Azure Container Apps certificate
- [x] Header forwarding: Fixed `input_headers` configuration

## 🔧 DNS Update Steps

### Step 1: Access Cloudflare Dashboard
1. Go to https://dash.cloudflare.com
2. Log in with your Cloudflare credentials
3. Select the domain: **voicelinkai.com**

### Step 2: Navigate to DNS Settings
1. Click on **DNS** in the left sidebar
2. You should see the **DNS Records** section

### Step 3: Update the Root Domain Record

**Current Configuration:**
```
Type: A
Name: voicelinkai.com (or @)
Content: 104.21.79.119, 172.67.145.111
Proxy Status: Proxied (🟠)
```

**New Configuration (Option A - CNAME):**
1. **Delete existing A records** for the root domain
2. **Add new CNAME record:**
   ```
   Type: CNAME
   Name: voicelinkai.com (or @)
   Target: voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io
   Proxy Status: Proxied (🟠) ← Keep this enabled!
   TTL: Auto
   ```

**New Configuration (Option B - A Record):**
If CNAME doesn't work for root domain:
```
Type: A
Name: voicelinkai.com (or @)
Content: 51.8.58.201
Proxy Status: Proxied (🟠) ← Keep this enabled!
TTL: Auto
```

### Step 4: Verify SSL Settings
1. Go to **SSL/TLS** → **Overview**
2. Ensure SSL mode is set to: **Full (strict)**
3. This ensures end-to-end encryption: Cloudflare ↔ Azure Container Apps

### Step 5: Save and Wait for Propagation
1. Click **Save** on the DNS record
2. Wait 2-5 minutes for Cloudflare's fast propagation
3. Cloudflare typically propagates much faster than traditional DNS

## 🧪 Testing the Update

### Immediate Test (Run this script):
```bash
./verify_dns_new.sh
```

### Manual Testing:
```bash
# 1. Check DNS resolution
dig +short A voicelinkai.com

# 2. Test the API endpoint
curl -s https://voicelinkai.com/api/v1/profile \
  -H "access-token: test" \
  -w "%{http_code}"

# Expected: 401 (authentication required)
```

### Success Indicators:
- ✅ `curl` returns HTTP **401** (not 000 or 502)
- ✅ DNS resolves to Cloudflare IPs (proxied)
- ✅ HTTPS works without certificate errors
- ✅ API endpoints require authentication (401 response)

## 🚨 Rollback Plan

If something goes wrong:

1. **Quick Rollback in Cloudflare:**
   - Go back to DNS Records
   - Delete the CNAME record
   - Add back the original A records:
     ```
     Type: A
     Name: voicelinkai.com
     Content: 104.21.79.119
     Proxy Status: Proxied (🟠)
     ```

2. **Verify Rollback:**
   ```bash
   curl -s https://voicelinkai.com/api/v1/profile -w "%{http_code}"
   ```

## 📊 Expected Architecture After Update

```
Internet User
    ↓
Cloudflare CDN/Proxy (104.21.79.119, 172.67.145.111)
    ↓
KrakenD Gateway (51.8.58.201)
    ↓
Chatwoot Backend (chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io)
```

## 🎉 Benefits After Update

- **DDoS Protection**: Cloudflare's protection layer
- **CDN**: Global content delivery network
- **API Gateway**: KrakenD request/response processing
- **Rate Limiting**: Both Cloudflare and KrakenD layers
- **SSL Termination**: Double SSL (Cloudflare + Azure)
- **Header Forwarding**: Fixed authentication flow
- **Monitoring**: Centralized logging and metrics

## 📞 Support

If you encounter issues:
1. Check the rollback steps above
2. Run `./verify_dns_new.sh` for diagnostics
3. Verify Cloudflare SSL settings are "Full (strict)"
4. Ensure the orange cloud (proxy) is enabled for DDoS protection 