# 🔧 Cloudflare SSL Fix Guide

## 🎯 Problem
- Cloudflare is handling SSL for `voicelinkai.com` ✅
- KrakenD is trying to handle SSL internally ❌
- Result: SSL handshake errors when Cloudflare tries to connect to KrakenD

## 🔍 Root Cause
**Double SSL Configuration**: Both Cloudflare and KrakenD are trying to handle SSL, causing conflicts.

## ✅ Solution

### Step 1: Fix Cloudflare SSL Mode
In your Cloudflare dashboard:

1. **Go to**: SSL/TLS → Overview
2. **Set SSL mode to**: `Full` (NOT "Full (strict)")
3. **Why**: This allows Cloudflare to connect to your backend over HTTP/HTTPS without strict certificate validation

### Step 2: Remove TLS from KrakenD
Deploy the SSL-free KrakenD configuration:

```bash
# Run the fix script
./fix_cloudflare_ssl.sh
```

### Step 3: Verify Cloudflare Settings
Ensure these settings in Cloudflare:

- **SSL/TLS Mode**: Full
- **Edge Certificates**: Enabled
- **Always Use HTTPS**: ON
- **Minimum TLS Version**: 1.2 or higher

## 🧪 Testing

After applying the fix:

```bash
# Test the domain
curl -I https://voicelinkai.com/health

# Should return HTTP 200 or 400 (not SSL errors)
```

## 🔄 DNS Configuration in Cloudflare

Your DNS should look like:
```
Type: A or CNAME
Name: voicelinkai.com (or @)
Target: voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io
Proxy: Enabled (orange cloud) ✅
```

## 🎯 Expected Flow

```
User → Cloudflare (SSL termination) → KrakenD (HTTP) → Chatwoot Backend
```

## 🚨 Common Issues

### Issue 1: "Full (strict)" SSL Mode
- **Problem**: Cloudflare requires valid SSL cert from backend
- **Solution**: Change to "Full" mode

### Issue 2: KrakenD Still Has TLS Config
- **Problem**: KrakenD tries to handle SSL internally
- **Solution**: Deploy `krakend-no-ssl.json`

### Issue 3: Registry Authentication
- **Problem**: Can't deploy new KrakenD image
- **Solution**: Fix managed identity permissions (script handles this)

## 🎉 Success Indicators

When working correctly:
- ✅ `https://voicelinkai.com` loads without SSL errors
- ✅ API calls work from frontend
- ✅ No "TLS handshake error" in KrakenD logs
- ✅ Cloudflare shows "Active" SSL certificate

## 🔧 Manual Fallback

If the script fails, manually:

1. **Update Cloudflare SSL mode** to "Full"
2. **In Azure Portal**: Update container image to `chatwootregistry95290.azurecr.io/krakend-no-ssl:latest`
3. **Test**: `curl -I https://voicelinkai.com/health` 