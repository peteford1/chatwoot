# Chatwoot Authentication System Diagnosis

## Executive Summary

After comprehensive analysis of the Chatwoot authentication system, I've identified the root causes of the API authentication failures and the correct authentication methods.

## Key Findings

### 1. Authentication Methods Supported

Based on source code analysis (`app/controllers/concerns/access_token_auth_helper.rb`), Chatwoot supports **both** authentication methods:

- **Legacy Method**: `api_access_token` header
- **Standard Method**: `Authorization: Bearer <token>` header  
- **Nginx Compatibility**: `HTTP_API_ACCESS_TOKEN` header

### 2. Database Token Analysis

✅ **Tokens Found in Database:**
- Platform App Tokens: 3 valid tokens exist
- User Tokens: 4 valid tokens exist  
- Super Admin Users: 1 exists with valid token

❌ **Critical Issues Identified:**
- Account 22 does not exist in database
- User tokens lack proper account associations
- Platform tokens may lack permissible resource associations

### 3. API Endpoint Structure

**Platform APIs**: `/platform/api/v1/*`
- Requires platform app tokens
- Needs `platform_app_permissibles` for resource access
- Routes exist in code but return 404 (not served)

**User APIs**: `/api/v1/*`  
- Requires user tokens
- Needs proper account associations
- Some endpoints return 404 (routing issues)

## Root Causes of Authentication Failures

### Issue 1: Platform API Routes Not Served (404 Errors)
- Platform API endpoints `/platform/api/v1/*` return 404
- Routes exist in `config/routes.rb` but not being served
- Possible causes:
  - Platform API feature disabled
  - Routing configuration issue
  - Missing middleware/controllers

### Issue 2: Missing Resource Associations
- Platform tokens need `platform_app_permissibles` records
- User tokens need `account_users` associations
- Without these, tokens return 401 even when valid

### Issue 3: Account 22 Missing
- All tests reference Account 22 which doesn't exist
- User tokens can't authenticate without valid account associations

## Authentication System Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   API Request   │───▶│  Authentication  │───▶│   Authorization │
│                 │    │     Headers      │    │    & Access     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │                         │
                              ▼                         ▼
                    ┌──────────────────┐    ┌─────────────────────┐
                    │ Token Validation │    │ Resource Permission │
                    │ (access_tokens)  │    │   (permissibles)    │
                    └──────────────────┘    └─────────────────────┘
```

## Correct Authentication Headers

### Method 1: Chatwoot Standard (Recommended)
```bash
curl -H 'api_access_token: YOUR_TOKEN' \
     -H 'Content-Type: application/json' \
     https://your-chatwoot.com/api/v1/profile
```

### Method 2: HTTP Standard  
```bash
curl -H 'Authorization: Bearer YOUR_TOKEN' \
     -H 'Content-Type: application/json' \
     https://your-chatwoot.com/api/v1/profile
```

### Method 3: Nginx Compatibility
```bash
curl -H 'HTTP_API_ACCESS_TOKEN: YOUR_TOKEN' \
     -H 'Content-Type: application/json' \
     https://your-chatwoot.com/api/v1/profile
```

## Solutions & Next Steps

### Immediate Fixes

1. **Create Account 22**
   ```ruby
   # Rails console
   Account.create!(id: 22, name: "Test Account")
   ```

2. **Associate User Tokens with Account**
   ```ruby
   # Rails console
   account = Account.find(22)
   user = User.find(3) # Stable API Admin
   account.account_users.create!(user: user, role: 'administrator')
   ```

3. **Create Platform App Permissibles**
   ```ruby
   # Rails console
   platform_app = PlatformApp.find(2)
   account = Account.find(22)
   platform_app.platform_app_permissibles.create!(permissible: account)
   ```

### Platform API Investigation

1. **Check if Platform API is enabled**
   ```ruby
   # Check if platform routes are loaded
   Rails.application.routes.routes.select { |r| r.path.spec.to_s.include?('platform') }
   ```

2. **Verify Platform Controllers Exist**
   ```bash
   ls app/controllers/platform/api/v1/
   ```

3. **Check Application Configuration**
   - Look for feature flags disabling platform API
   - Check environment-specific configurations

### Testing Working Authentication

Once associations are fixed, test with:

```bash
# Test user token (after account association)
curl -H 'api_access_token: J8mwDmmcZbuYs6a672oT8TW6' \
     https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile

# Test platform token (after permissibles created)  
curl -H 'api_access_token: SamnuRSUjB4ZpktAqhLqxjeZ' \
     https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/accounts
```

## Conclusion

The Chatwoot authentication system is correctly implemented and supports multiple authentication methods. The failures are due to:

1. **Missing database associations** (accounts, permissibles)
2. **Platform API routing issues** (404 responses)
3. **Incomplete test data setup** (missing Account 22)

The authentication headers and token validation work correctly - the issue is in the authorization layer where tokens lack the necessary resource associations to access data.

**Recommended Action**: Fix the database associations first, then investigate why platform API routes return 404. 