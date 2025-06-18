# 🚨 IMMEDIATE CLOUDFLARE SSL FIX

## 🎯 The Problem
- **Error**: `curl: (35) Recv failure: Connection reset by peer`
- **Cause**: Cloudflare is trying to connect to KrakenD over HTTPS, but KrakenD expects SSL certificates that don't exist
- **Solution**: Change Cloudflare to connect over HTTP instead

## ✅ IMMEDIATE FIX (5 minutes)

### Step 1: Update Cloudflare SSL Mode
**This is the critical fix that will solve your SSL errors immediately:**

1. **Login to Cloudflare Dashboard**
2. **Select your domain**: `voicelinkai.com`
3. **Go to**: SSL/TLS → Overview
4. **Change SSL/TLS encryption mode** from `Full (strict)` to `Full`

   **Current (causing errors)**: `Full (strict)` 
   **Change to**: `Full`

5. **Save the changes**

### Step 2: Verify DNS Settings
In Cloudflare DNS:
```
Type: CNAME
Name: voicelinkai.com (or @)
Target: voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io
Proxy Status: Proxied (orange cloud) ✅
```

### Step 3: Test Immediately
```bash
# Wait 2-3 minutes for Cloudflare to propagate, then test:
curl -I https://voicelinkai.com/health

# Should return HTTP 400 or 200 (not connection reset)
```

## 🔍 Why This Works

**Before (Broken)**:
```
User → Cloudflare (HTTPS) → KrakenD (expects HTTPS with certs) → ❌ SSL Error
```

**After (Fixed)**:
```
User → Cloudflare (HTTPS) → KrakenD (HTTP) → ✅ Works
```

## 🎯 SSL Mode Explanation

- **Full (strict)**: Cloudflare requires valid SSL certificate from your backend ❌
- **Full**: Cloudflare encrypts to backend but doesn't validate certificate ✅
- **Flexible**: Cloudflare to backend is HTTP (less secure)

## 🧪 Testing Commands

```bash
# Test main domain
curl -I https://voicelinkai.com/health

# Test API endpoint
curl -I https://voicelinkai.com/api/v1/widget/config

# Test direct backend (should still work)
curl -I https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io/health
```

## 🎉 Expected Results

After changing to "Full" mode:
- ✅ No more SSL handshake errors
- ✅ `https://voicelinkai.com` works
- ✅ Your frontend can connect to APIs
- ✅ Cloudflare still provides SSL to users

## 🚨 If Still Not Working

1. **Clear Cloudflare cache**: Purge Everything in Caching tab
2. **Wait 5 minutes** for DNS propagation
3. **Check KrakenD logs**:
   ```bash
   az containerapp logs show --name voicelinkai-gateway-instance-v32 --resource-group SM-Test --tail 10
   ```

## 💡 Alternative Quick Fix

If changing SSL mode doesn't work immediately, temporarily:

1. **Set SSL mode to "Flexible"** (HTTP to backend)
2. **Test if it works**
3. **Then change back to "Full"** for better security

---

## 🎯 SUMMARY

**The ONE change that will fix your SSL errors:**
**Cloudflare SSL/TLS mode: `Full (strict)` → `Full`**

This should resolve your SSL handshake errors within 2-3 minutes! 