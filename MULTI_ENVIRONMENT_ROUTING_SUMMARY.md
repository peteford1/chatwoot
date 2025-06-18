# Multi-Environment Path-Based Routing Summary

## 🎯 **IMPLEMENTED: Option 1 - Path-Based Routing**

A single KrakenD instance now routes traffic to different environments based on URL paths.

## 📍 **Routing Configuration**

### **Current Active Routes**
```
www.voicelinkai.com/api           → Multi-environment status page
www.voicelinkai.com/health        → Production backend health
www.voicelinkai.com/              → Production backend (default)
www.voicelinkai.com/api/v1/*      → Production backend
www.voicelinkai.com/prod/*        → Production backend (explicit)
www.voicelinkai.com/dev/*         → Development backend (ready for deployment)
www.voicelinkai.com/staging/*     → Staging backend (ready for deployment)
```

### **Environment Mapping**
- **🟢 Production**: `/prod/*` or `/` → `chatwoot-test` ✅ **ACTIVE**
- **🟡 Development**: `/dev/*` → `chatwoot-dev` 🔧 **READY** (backend pending)
- **🟠 Staging**: `/staging/*` → `chatwoot-staging` 🔧 **READY** (backend pending)

## 🔧 **Current Container Configuration**

### Environment Variables
```bash
KRAKEND_ENVIRONMENT=multi-env
KRAKEND_PROD_BACKEND_URL=https://chatwoot-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io
# KRAKEND_DEV_BACKEND_URL=<pending>
# KRAKEND_STAGING_BACKEND_URL=<pending>
```

### Docker Image
- **Image**: `voicelinkregistry.azurecr.io/krakend-gateway:chatwoot-test-v1`
- **Base**: `devopsfaith/krakend:2.6`
- **Configuration**: `/etc/krakend/environments/multi-env/krakend.json`

## 🧪 **Testing Results**

### ✅ **Working Endpoints**
```bash
# Multi-environment status
curl http://voicelinkai.com/api
# Returns: {"status":"healthy","environment":"multi-environment","routing":{...}}

# Health check
curl http://voicelinkai.com/health
# Routes to production backend

# Production routes (all working)
curl http://voicelinkai.com/prod/api
curl http://voicelinkai.com/api/v1/accounts
curl http://voicelinkai.com/
```

### 🔧 **Ready But Pending Backends**
```bash
# Development routes (KrakenD ready, backend needed)
curl http://voicelinkai.com/dev/api
curl http://voicelinkai.com/dev/api/v1/accounts

# Staging routes (KrakenD ready, backend needed)
curl http://voicelinkai.com/staging/api
curl http://voicelinkai.com/staging/api/v1/accounts
```

## 📋 **Next Steps to Complete Setup**

### 1. Create Development Backend
```bash
# Deploy chatwoot-dev container app
az containerapp create --name chatwoot-dev --resource-group SM-Test \
  --image <your-chatwoot-image> \
  --environment chatwoot-env-test \
  --ingress external --target-port 3000

# Update KrakenD with dev backend URL
az containerapp update --name voicelinkai-gateway-instance-v32 \
  --resource-group SM-Test \
  --set-env-vars KRAKEND_DEV_BACKEND_URL=https://chatwoot-dev.calmmushroom-30b1c815.eastus.azurecontainerapps.io
```

### 2. Create Staging Backend
```bash
# Deploy chatwoot-staging container app
az containerapp create --name chatwoot-staging --resource-group SM-Test \
  --image <your-chatwoot-image> \
  --environment chatwoot-env-test \
  --ingress external --target-port 3000

# Update KrakenD with staging backend URL
az containerapp update --name voicelinkai-gateway-instance-v32 \
  --resource-group SM-Test \
  --set-env-vars KRAKEND_STAGING_BACKEND_URL=https://chatwoot-staging.calmmushroom-30b1c815.eastus.azurecontainerapps.io
```

## 🏗️ **Architecture**

### Current Architecture
```
Internet → Cloudflare → voicelinkai-gateway-instance-v32 (KrakenD Multi-Env)
                                    ↓
                        ┌─────────────────────────┐
                        │   Path-Based Router     │
                        └─────────────────────────┘
                                    ↓
        ┌─────────────────┬─────────────────┬─────────────────┐
        ↓                 ↓                 ↓                 ↓
   /dev/* (ready)    /staging/* (ready)   /prod/* or /     /api
        ↓                 ↓                 ↓                 ↓
 chatwoot-dev      chatwoot-staging    chatwoot-test      Status Page
   (pending)         (pending)          ✅ ACTIVE        ✅ ACTIVE
```

### Future Complete Architecture
```
Internet → Cloudflare → KrakenD Multi-Environment Gateway
                                    ↓
        ┌─────────────────┬─────────────────┬─────────────────┐
        ↓                 ↓                 ↓                 ↓
   /dev/* routes     /staging/* routes   /prod/* routes    /api
        ↓                 ↓                 ↓                 ↓
   chatwoot-dev      chatwoot-staging   chatwoot-test      Status
  (Development)       (Staging)        (Production)       (Health)
```

## 🔍 **Configuration Features**

### **Path Routing**
- **Wildcard Support**: `/{path}` captures all sub-paths
- **Method Support**: GET, POST, PUT, DELETE, PATCH, OPTIONS
- **Header Injection**: Adds `X-Environment` headers to requests
- **Response Headers**: Adds `X-Gateway-Environment` to responses

### **Backend URL Replacement**
- **Runtime Configuration**: Environment variables override config URLs
- **Multi-Backend Support**: Separate URLs for each environment
- **Legacy Support**: `KRAKEND_BACKEND_URL` still works for production

### **Health & Monitoring**
- **Status Endpoint**: `/api` shows routing configuration
- **Health Endpoint**: `/health` checks production backend
- **Environment Headers**: Track which environment handled the request

## 💰 **Cost Impact**
- **No Additional Cost**: Uses existing KrakenD container
- **Efficient Routing**: Single gateway handles all environments
- **Resource Optimization**: Shared infrastructure across environments

## 🚀 **Deployment Ready**
- **GitHub Actions**: Use existing workflow in `.github/workflows/deploy-krakend-gateway.yml`
- **Environment Variables**: Easy backend URL updates
- **Scalable**: Ready for additional environments

---

## 🎉 **Status: MULTI-ENVIRONMENT ROUTING IMPLEMENTED** ✅

**Single KrakenD instance now supports path-based routing to multiple environments:**
- ✅ **Production**: `/prod/*` or `/` → `chatwoot-test`
- 🔧 **Development**: `/dev/*` → Ready for `chatwoot-dev` backend
- 🔧 **Staging**: `/staging/*` → Ready for `chatwoot-staging` backend

**Next**: Deploy the missing `chatwoot-dev` and `chatwoot-staging` backends to complete the setup. 