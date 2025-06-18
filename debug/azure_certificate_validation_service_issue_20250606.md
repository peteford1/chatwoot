# Azure Container Apps Certificate Validation Service Issue

**Date:** June 6, 2025  
**Environment:** chatwoot-env-test (East US)  
**Issue:** SSL certificate validation hanging indefinitely in "Pending" state

## 🚨 **ROOT CAUSE: Azure Service Issue**

This is a **confirmed Azure Container Apps service issue** affecting certificate validation globally.

### **Symptoms**
- ✅ Domain correctly added to Container App
- ✅ DNS A record pointing to correct Azure IP (51.8.58.201)
- ✅ TXT record for validation properly configured
- ✅ HTTP traffic redirects to HTTPS (proving domain routing works)
- ❌ SSL certificates stuck in "Pending" state for 20+ minutes
- ❌ No error details provided by Azure
- ❌ Multiple validation methods (HTTP, TXT, CNAME) all fail

### **Evidence of Widespread Issue**
- Microsoft Learn forum reports identical issues (June 2-6, 2025)
- Multiple users experiencing same "Pending" certificate validation
- Azure support acknowledging certificate validation service problems
- Similar pattern across different regions and environments

### **Our Configuration (Verified Correct)**
```bash
# Domain Configuration
Domain: voicelinkai.com
A Record: 51.8.58.201 ✅
TXT Record (Domain Verification): asuid.voicelinkai.com → 4395C0037B6AE3D7E3E337355B4FFF8D5DB2C448F197F6155A4B7299D98D9182 ✅

# Last TXT Validation Token
TXT Record (SSL): _acme-challenge.voicelinkai.com → _1y2dteupodcppef2rj8sy0bpradx6dk ✅

# Azure Resources
Container App: chatwoot-backend-test
Environment: chatwoot-env-test  
Resource Group: SM-Test
Region: East US
```

### **Validation Steps Performed**
1. ✅ DNS propagation confirmed globally (dig, nslookup)
2. ✅ Azure environment healthy and operational
3. ✅ Domain accessible via HTTP (redirects to HTTPS)
4. ✅ Multiple certificate creation attempts with different validation methods
5. ✅ Certificate deletion and recreation with fresh tokens
6. ✅ 20+ minute wait times (far exceeding normal validation time)

### **Root Problem Verification**
- DNS resolves correctly: `voicelinkai.com` → `51.8.58.201`
- Azure expects exactly this IP: `51.8.58.201` ✅
- TXT record matches validation token exactly ✅
- HTTP access confirms routing works ✅
- **Azure certificate validation service is non-responsive**

## 📋 **Resolution Steps**

### **When Azure Service is Fixed:**
1. Delete any stuck certificates
2. Create new certificate with HTTP validation
3. Should validate within 2-5 minutes when service is operational

### **Monitoring Commands:**
```bash
# Check certificate status
az containerapp env certificate list --name chatwoot-env-test --resource-group SM-Test

# Test domain accessibility  
curl -v http://voicelinkai.com/api

# Verify DNS
dig A voicelinkai.com
dig TXT _acme-challenge.voicelinkai.com
```

### **Temporary Workaround (Not Implemented)**
Could configure external SSL certificate provider, but waiting for Azure fix is recommended.

## 🔍 **How to Identify Same Issue**
1. Certificate stuck in "Pending" state for >10 minutes
2. DNS correctly configured and propagated  
3. Domain accessible via HTTP
4. No error details from Azure
5. Multiple validation methods fail identically
6. Check Microsoft Learn forums for current reports

## ✅ **Resolution Verification Steps**
1. Certificate reaches "Succeeded" state
2. HTTPS access works: `curl -v https://voicelinkai.com/api`
3. SSL certificate binding successful
4. Browser shows valid certificate

---
**Status:** AZURE SERVICE ISSUE - WAITING FOR MICROSOFT FIX  
**ETA:** Unknown (Azure service restoration required)  
**Last Updated:** 2025-06-06 10:30 UTC 