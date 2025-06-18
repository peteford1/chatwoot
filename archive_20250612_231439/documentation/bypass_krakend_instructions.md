# Bypass KrakenD - Direct Backend Access Instructions

## 🎯 Problem
KrakenD has a confirmed header forwarding issue preventing authentication. Need to bypass it temporarily.

## 📊 Current Setup
- **Domain:** `voicelinkai.com` → `104.21.79.119` (Cloudflare → KrakenD)
- **Backend:** `chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io` → `51.8.58.201`

## 🚀 Solution Options

### Option 1: Update Cloudflare DNS (Recommended)

1. **Log into Cloudflare Dashboard**
   - Go to: https://dash.cloudflare.com/
   - Select the `voicelinkai.com` domain

2. **Update A Record**
   ```
   Type: A
   Name: @ (or voicelinkai.com)
   Content: 51.8.58.201  # Backend IP
   TTL: Auto (or 300 for fast updates)
   Proxy Status: 🟠 DNS only (turn OFF proxy)
   ```

3. **Update CNAME Alternative** (If using CNAME)
   ```
   Type: CNAME  
   Name: @ (or voicelinkai.com)
   Content: chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io
   TTL: Auto
   Proxy Status: 🟠 DNS only
   ```

### Option 2: Create Temporary Subdomain

Create a new subdomain that points directly to backend:

1. **Add DNS Record in Cloudflare**
   ```
   Type: CNAME
   Name: direct (creates direct.voicelinkai.com)
   Content: chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io
   TTL: 300
   Proxy Status: 🟠 DNS only
   ```

2. **Test Access**
   ```bash
   curl -X GET "https://direct.voicelinkai.com/api/v1/profile" \
     -H "access-token: [TOKEN]" \
     -H "client: [CLIENT]" \
     -H "uid: admin@voicelinkai.com"
   ```

### Option 3: Update Frontend Configuration

Update frontend to use backend URL directly:

1. **Environment Variables**
   ```bash
   # Update these in your frontend app
   REACT_APP_API_BASE_URL=https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io
   VUE_APP_API_BASE_URL=https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io
   ```

2. **CORS Configuration**
   Make sure Chatwoot backend allows your domain:
   ```ruby
   # In config/application.rb or cors.rb
   config.cors.allow_origin = ['https://voicelinkai.com', 'https://direct.voicelinkai.com']
   ```

## 🧪 Testing

### Test Direct Backend Access
```bash
# 1. Get fresh tokens
curl -X POST "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@voicelinkai.com","password":"SuperAdmin123!"}'

# 2. Test authenticated endpoint  
curl -X GET "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile" \
  -H "access-token: [TOKEN]" \
  -H "client: [CLIENT]" \
  -H "uid: admin@voicelinkai.com"
```

### Test After DNS Update
```bash
# Wait 5-10 minutes for DNS propagation, then test:
curl -X GET "https://voicelinkai.com/api/v1/profile" \
  -H "access-token: [TOKEN]" \
  -H "client: [CLIENT]" \
  -H "uid: admin@voicelinkai.com"
```

## ⚡ Quick Implementation (Option 1)

Here's the fastest way to implement:

```bash
# 1. Update DNS in Cloudflare
# Point voicelinkai.com A record to: 51.8.58.201

# 2. Test immediately with host override
curl -X GET "https://voicelinkai.com/api/v1/profile" \
  --resolve "voicelinkai.com:443:51.8.58.201" \
  -H "access-token: [TOKEN]" \
  -H "client: [CLIENT]" \
  -H "uid: admin@voicelinkai.com"
```

## 🔒 SSL Certificate Considerations

**Important:** Make sure the backend has SSL certificates for `voicelinkai.com` domain, or:

1. **Use backend domain directly:** `chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io`
2. **Configure SSL on backend** for `voicelinkai.com`
3. **Use Cloudflare proxy** with backend as origin (but ensure CORS)

## 📝 Rollback Plan

If issues occur, revert DNS:
```
Type: A
Name: @
Content: 104.21.79.119  # Back to KrakenD
```

## ✅ Benefits of Bypassing KrakenD

- ✅ **Authentication works** (confirmed in testing)
- ✅ **Faster response times** (no proxy overhead)  
- ✅ **Simpler architecture** (fewer failure points)
- ✅ **Better debugging** (direct backend logs)

## 🔧 Next Steps After Bypass

1. **Monitor performance** and stability
2. **Fix KrakenD configuration** in parallel
3. **Consider alternative API gateways** (Nginx, Traefik, Kong)
4. **Implement proper load balancing** if needed 