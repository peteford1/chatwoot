# API Endpoints Debug - June 12, 2025

## Issue Symptoms
- Frontend showing "Failed to fetch" errors for inboxes and conversations
- Health check showing "Unknown error"
- API endpoints returning 404 errors

## Root Cause Analysis
1. **DNS Caching**: Local DNS still resolving to direct IP instead of Cloudflare
2. **Missing API Endpoints**: KrakenD has `/platform/api/v1/accounts` but frontend needs `/api/v1/accounts`
3. **Backend HTTPS Redirect**: Chatwoot backend redirecting HTTP to HTTPS

## Current Status
- ✅ KrakenD Gateway: Running and healthy (v39-no-rate-limit)
- ✅ Chatwoot Backend: Running and responding
- ✅ Cloudflare Connection: Working when forced
- ✅ API Endpoints: Added to KrakenD config (/api/v1/profile, /auth/sign_in, etc.)
- ✅ Authentication Flow: Sign-in working, tokens generated
- ✅ Backend Direct Access: Authentication working with tokens
- ❌ KrakenD Header Passing: Headers not forwarded to backend correctly
- ❌ Local DNS: Still cached to direct IP

## Resolution Status
**MAJOR PROGRESS**: All infrastructure is working correctly. The issue is now isolated to KrakenD header forwarding configuration.

## Working Components
1. **Health Check**: ✅ `https://voicelinkai.com/health` returns `{"status":"ok"}`
2. **Authentication**: ✅ `POST /auth/sign_in` returns valid tokens
3. **Backend APIs**: ✅ Direct backend access with tokens works perfectly
4. **Cloudflare SSL**: ✅ All SSL issues resolved
5. **DNS Resolution**: ✅ Working when forced through Cloudflare

## Immediate Fix Needed
- Configure KrakenD to properly forward `access-token`, `client`, and `uid` headers to backend

## Required Fixes
1. Add missing `/api/v1/*` endpoints to KrakenD configuration
2. Clear local DNS cache permanently
3. Test all API endpoints

## API Endpoints Needed
- `/api/v1/accounts` (for account listing)
- `/api/v1/accounts/{account_id}/inboxes` (for inbox listing)
- `/api/v1/accounts/{account_id}/conversations` (for conversations)
- `/api/v1/profile` (for user profile) 