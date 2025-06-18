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

# Cloudflare SSL/TLS Configuration Fix

## 🔍 **Issue Identified: HTTP 525 Error**

**Problem**: Cloudflare SSL/TLS mode is set to "Flexible" but Azure Container Apps requires HTTPS.

## 🧪 **Test Results Confirming Issue:**

### ✅ HTTP Works (through Cloudflare):
```bash
curl -s -o /dev/null -w "%{http_code}" http://voicelinkai.com/api/v1/profile -H "access-token: test" --resolve voicelinkai.com:80:104.21.79.119
# Result: 401 (authentication required - PERFECT!)
```

### ❌ HTTPS Fails (Cloudflare → Azure SSL issue):
```bash
curl -s -o /dev/null -w "%{http_code}" https://voicelinkai.com/api/v1/profile -H "access-token: test" --resolve voicelinkai.com:443:104.21.79.119
# Result: 525 (SSL handshake failed between Cloudflare and origin)
```

### ✅ Direct Gateway Works:
```bash
curl -s -o /dev/null -w "%{http_code}" https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile -H "access-token: test"
# Result: 401 (authentication required - PERFECT!)
```

## 🔧 **Required Fix: Change SSL/TLS Mode**

### **Current Configuration (Causing 525 Error):**
```
SSL/TLS Mode: Flexible
Browser ↔ Cloudflare: HTTPS ✅
Cloudflare ↔ Azure: HTTP ❌ (Azure requires HTTPS)
```

### **Required Configuration:**
```
SSL/TLS Mode: Full (or Full strict)
Browser ↔ Cloudflare: HTTPS ✅
Cloudflare ↔ Azure: HTTPS ✅
```

## 📋 **Step-by-Step Fix:**

1. **Go to Cloudflare Dashboard**: https://dash.cloudflare.com
2. **Select Domain**: voicelinkai.com
3. **Navigate to**: SSL/TLS → Overview
4. **Change SSL/TLS Mode**: From "Flexible" to **"Full"**
5. **Save Changes**

## 🎯 **Expected Result After Fix:**

```bash
# HTTPS will work through Cloudflare
curl -s -o /dev/null -w "%{http_code}" https://voicelinkai.com/api/v1/profile -H "access-token: test"
# Expected: 401 (authentication required)

# Verification script will pass
./verify_dns_new.sh
# Expected: Both HTTP and HTTPS return 401
```

## 🏗️ **Architecture After Fix:**

```
Internet User
    ↓ HTTPS (Cloudflare SSL certificate)
Cloudflare CDN/Proxy
    ↓ HTTPS (Azure Container Apps SSL certificate)
KrakenD Gateway (voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io)
    ↓ HTTPS
Chatwoot Backend
```

## 🚨 **Why This Happens:**

- **Azure Container Apps** only accept HTTPS connections
- **Cloudflare "Flexible" mode** tries to connect via HTTP
- **Result**: SSL handshake failure (HTTP 525)
- **Solution**: Enable HTTPS between Cloudflare and Azure

## ⏱️ **Time to Fix:**
- **Change setting**: 30 seconds
- **Propagation**: 1-2 minutes
- **Total**: Under 3 minutes

**Status**: One setting change away from complete success! 🚀 