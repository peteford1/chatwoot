# 🎯 DEBUG RECORD: Widget Routes & ActionCable Integration Success

**Date:** 2025-06-04 07:30:00  
**Issue Type:** Integration Setup & Troubleshooting  
**Status:** ✅ RESOLVED - Production Ready  
**Root Cause:** API-only backend limitations and missing ActionCable mount

---

## 🔍 **SYMPTOMS IDENTIFIED**
1. Frontend team unable to access widget routes (`/widget/config/{token}` returning 404)
2. Cable endpoints (`/cable` returning 404)  
3. API-only backend not providing full frontend functionality
4. Real-time WebSocket features unavailable

## 🛠️ **DIAGNOSTIC STEPS PERFORMED**

### **Step 1: Widget Route Analysis**
- **Finding:** Widget routes were actually available at `/api/v1/widget/*` not `/widget/*`
- **Validation:** `POST /api/v1/widget/config` with website_token working correctly
- **Endpoint Confirmed:** Returns complete widget configuration and auth tokens

### **Step 2: ActionCable Investigation**  
- **Finding:** ActionCable mount present in routes but not working with API-only mode
- **Issue:** `CW_API_ONLY_SERVER=true` was limiting functionality
- **Routes Check:** `mount ActionCable.server => '/cable'` was correctly configured

### **Step 3: Full Installation Deployment**
- **Action:** Deployed latest Chatwoot image with `CW_API_ONLY_SERVER=false`
- **Result:** Full frontend functionality restored
- **Verification:** WebSocket connections confirmed working via server logs

## ✅ **RESOLUTION ACTIONS**

### **1. Environment Configuration**
```bash
# Updated key environment variables
CW_API_ONLY_SERVER=false          # Enable full installation
RAILS_ENV=production              # Production environment  
FRONTEND_URL=https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io
```

### **2. Image Deployment**
```bash
# Built and deployed full Chatwoot installation
docker build --platform linux/amd64 -f Dockerfile.azure -t chatwootregistry95290.azurecr.io/chatwoot-full:v2 .
az containerapp update --name chatwoot-backend-test --image chatwootregistry95290.azurecr.io/chatwoot-full:v2
```

### **3. Scaling Optimization**
```bash
# Configured auto-scaling for production use
az containerapp update --name chatwoot-backend-test --min-replicas 1 --max-replicas 3
```

## 🎯 **VERIFICATION CRITERIA**

Use these steps to verify the same root problem in similar issues:

### **Primary Indicators:**
1. `curl -X POST -H "Content-Type: application/json" -d '{"website_token":"zEGFZ3658VdbbvkCTrpy8C5z"}' .../api/v1/widget/config` returns 200 OK
2. Server logs show `Started GET "/cable" [WebSocket]` for real-time connections
3. Frontend dashboard loads at `/app` with `window.chatwootConfig` present
4. Environment variable `CW_API_ONLY_SERVER=false` for full functionality

### **Secondary Indicators:**
- Widget auth tokens generated successfully
- ActionCable mount visible in routes: `cable` ActionCable [WebSocket]
- Container scaling configured appropriately
- CORS allows widget domain origins

## 🚀 **RESOLUTION STEPS**

When encountering similar widget/ActionCable integration issues:

### **1. Verify Widget API Endpoints**
```bash
# Test widget configuration endpoint
curl -X POST -H "Content-Type: application/json" \
  -d '{"website_token":"YOUR_WEBSITE_TOKEN"}' \
  https://YOUR_DOMAIN/api/v1/widget/config

# Should return 200 OK with widget configuration
```

### **2. Check ActionCable Configuration**
```bash
# Verify ActionCable mount in routes
az containerapp exec --command "bundle exec rails routes | grep cable"

# Check for WebSocket connections in logs
az containerapp logs show --follow false --tail 20 | grep -i cable
```

### **3. Update to Full Installation**
```bash
# Set environment for full Chatwoot (not API-only)
az containerapp update --set-env-vars CW_API_ONLY_SERVER=false

# Deploy latest full Chatwoot image
az containerapp update --image chatwoot/chatwoot:latest
```

### **4. Configure Production Scaling**
```bash
# Set appropriate scaling for production use
az containerapp update --min-replicas 1 --max-replicas 3
```

## 📊 **FINAL CONFIGURATION**

### **Working Endpoints:**
- **Widget Config:** `POST /api/v1/widget/config` ✅
- **WebSocket:** `wss://.../cable` ✅  
- **Dashboard:** `GET /app` ✅
- **API Health:** `GET /api` ✅

### **Environment Variables:**
- `CW_API_ONLY_SERVER=false` ✅
- `RAILS_ENV=production` ✅
- `FRONTEND_URL=https://...` ✅
- Scaling: 1-3 replicas ✅

### **Access Credentials:**
- **Website Token:** `zEGFZ3658VdbbvkCTrpy8C5z`
- **Admin Email:** `admin@chatwoot.com`  
- **Admin Password:** `Password123!`

## 🎯 **SUCCESS METRICS**

**Integration Status: PRODUCTION READY ✅**

- [x] Widget routes accessible and functional
- [x] ActionCable WebSocket connections working  
- [x] Real-time messaging features enabled
- [x] Auto-scaling configured (1-3 replicas)
- [x] Full frontend functionality available
- [x] CORS properly configured for external domains
- [x] SSL/HTTPS working correctly
- [x] Integration documentation provided

**Resolution Time:** ~2 hours  
**Components Updated:** Container app environment, Docker image, scaling configuration  
**Testing Completed:** Widget API, WebSocket connections, dashboard access, scaling verification

---

**📝 Notes for Future Reference:**
- API-only mode (`CW_API_ONLY_SERVER=true`) limits widget functionality
- ActionCable requires full installation to work properly with external frontends
- WebSocket connections require HTTP/1.1 protocol for proper upgrade
- Container restart may be needed after environment variable changes
- Scaling configuration should be set for production workloads

**✅ Issue Resolution: COMPLETE & PRODUCTION READY** 