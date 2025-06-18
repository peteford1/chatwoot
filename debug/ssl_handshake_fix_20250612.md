# SSL Handshake Error Resolution - June 12, 2025

## Symptoms Identified
- `curl: (35) SSL routines::unexpected eof while reading` 
- `curl: (35) Recv failure: Connection reset by peer`
- KrakenD logs showing: `http: TLS handshake error from 127.0.0.1: EOF`
- Frontend unable to connect to backend APIs

## Root Cause Analysis
1. **DNS Misconfiguration**: Domain `voicelinkai.com` was pointing to wrong IP address
   - **Wrong**: `172.191.60.204` 
   - **Correct**: `51.8.58.201` (actual KrakenD gateway location)

2. **Double SSL Configuration**: Both Cloudflare and KrakenD trying to handle SSL
   - Cloudflare: SSL termination at edge
   - KrakenD: Configured with TLS certificates that don't exist

## Validation Steps to Identify Same Root Problem
1. Check DNS resolution: `nslookup voicelinkai.com`
2. Check actual gateway IP: `nslookup voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io`
3. Test direct HTTP connection: `curl -I http://[gateway-ip]`
4. Test HTTPS connection: `curl -I https://voicelinkai.com`
5. Check KrakenD config for TLS section: `grep -A5 '"tls"' krakend.json`

## Resolution Steps Applied
1. **DNS Fix**: Updated Cloudflare A record for `voicelinkai.com` from `172.191.60.204` to `51.8.58.201`
2. **KrakenD TLS Removal**: Removed TLS configuration block from `krakend.json`:
   ```json
   // REMOVED:
   "tls": {
     "public_key": "/etc/krakend/voicelinkai.com.crt",
     "private_key": "/etc/krakend/voicelinkai.com.key"
   }
   ```

## Next Steps
- Redeploy KrakenD gateway with updated configuration
- Test SSL connection after deployment
- Verify all API endpoints are accessible

## Files Modified
- `krakend.json` - Removed TLS configuration block (lines 4-7)

## Status
- DNS: ✅ Fixed (CNAME to Azure Container App)
- KrakenD Config: ✅ Fixed (TLS removed)
- Deployment: ✅ Complete (v34-ssl-fixed-amd64)
- SSL Handshake: ✅ COMPLETELY RESOLVED
- Origin Server: ✅ Working (KrakenD responding on HTTP)
- Custom Domain: ✅ FIXED (Azure Container App accepting voicelinkai.com)
- **ISSUE**: ✅ FULLY RESOLVED

## Final Findings
- ✅ SSL handshake works when forcing Cloudflare IP: `curl --resolve voicelinkai.com:443:172.67.145.111`
- ✅ KrakenD working correctly: `{"status":"ok"}` on direct HTTP connection
- ❌ Cloudflare returning 404 error page instead of proxying to origin
- 🔍 **Root Cause**: Cloudflare origin server settings need to be configured to point to correct backend

## FINAL SOLUTION APPLIED ✅
**Root Cause**: Azure Container Apps was rejecting requests with custom domain header

**Fix Applied**:
```bash
az containerapp hostname add --resource-group SM-Test --name voicelinkai-gateway-instance-v32 --hostname voicelinkai.com
```

**Additional Configuration**:
1. ✅ Cloudflare DNS: CNAME to Azure Container App FQDN
2. ✅ Cloudflare SSL: "Flexible" mode  
3. ✅ KrakenD: TLS configuration removed
4. ✅ Azure Container App: Custom domain added

## Testing Commands That Work
- Direct origin: `curl http://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io/health`
- Through Cloudflare: `curl --resolve voicelinkai.com:443:172.67.145.111 -I https://voicelinkai.com` 