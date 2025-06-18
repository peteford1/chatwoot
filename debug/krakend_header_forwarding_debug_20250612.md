# KrakenD Header Forwarding Debug - June 12, 2025

## Problem
KrakenD is not properly forwarding authentication headers (`access-token`, `client`, `uid`) to the Chatwoot backend, resulting in 401 unauthorized errors.

## Symptoms
- Authentication works: `POST /auth/sign_in` returns valid tokens
- Direct backend access works: Backend responds with 200 when headers are passed directly
- KrakenD proxy fails: Returns 401 when same headers are passed through KrakenD

## Verification Tests

### ✅ Authentication Working
```bash
curl -X POST "https://voicelinkai.com/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@voicelinkai.com","password":"SuperAdmin123!"}' \
  --resolve "voicelinkai.com:443:104.21.79.119"
# Returns: access-token: gMOKXvFlRzbsscw0eXvldA, client: 9uelrVX_1bW2EQHiSkXEBQ
```

### ✅ Direct Backend Working
```bash
curl -X GET "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile" \
  -H "access-token: gMOKXvFlRzbsscw0eXvldA" \
  -H "client: 9uelrVX_1bW2EQHiSkXEBQ" \
  -H "uid: admin@voicelinkai.com"
# Returns: 200 OK with user profile
```

### ❌ KrakenD Proxy Failing
```bash
curl -X GET "https://voicelinkai.com/api/v1/profile" \
  -H "access-token: gMOKXvFlRzbsscw0eXvldA" \
  -H "client: 9uelrVX_1bW2EQHiSkXEBQ" \
  -H "uid: admin@voicelinkai.com" \
  --resolve "voicelinkai.com:443:104.21.79.119"
# Returns: 401 {"errors":["You need to sign in or sign up before continuing."]}
```

## Configuration Attempts

### Attempt 1: Wildcard Headers
- Used `"headers_to_pass": ["*"]`
- Result: Still 401

### Attempt 2: Explicit Headers
- Used specific header list: `["Content-Type", "Authorization", "access-token", "client", "uid", "token-type", "expiry", "User-Agent"]`
- Result: Still 401

### Attempt 3: CORS Allow Credentials
- Changed `"allow_credentials": false` to `"allow_credentials": true`
- Result: Still 401

## Current Configuration
- KrakenD Version: 2.4.6
- Docker Image: `voicelinkcrm.azurecr.io/voicelinkai-gateway:v42-allow-credentials`
- Backend: `https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io`

## Next Steps to Try
1. Add debug logging to see what headers KrakenD is actually sending
2. Try using `modifier/martian` for explicit header manipulation
3. Check if there's a KrakenD version issue
4. Consider using a different proxy approach

## Root Cause Hypothesis
KrakenD 2.4.6 may have a bug with header forwarding for headers containing hyphens (`access-token`) or may be stripping authentication headers despite configuration. 