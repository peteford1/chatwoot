# Docker Image Gem Dependency Issue

**Date:** 2025-06-11 19:36:00
**Container:** chatwoot-backend-test
**Image:** chatwootregistry95290.azurecr.io/chatwoot-full:v6-final

## Problem Description
The Docker image is failing to start with a gem dependency error during Rails application boot.

## Error Details
```
LoadError: cannot load such file -- devise-secure_password (LoadError)
Did you mean?  devise/secure_password
Location: /app/config/application.rb:9
```

## Root Cause Analysis
The error occurs in the application configuration file, suggesting:
1. Missing `devise-secure_password` gem in the Docker image
2. Incorrect gem name reference (should be `devise/secure_password`)
3. Incomplete bundle install in Docker image build

## Environment Variables Tested
- ✅ DATABASE_URL: Set correctly
- ✅ SECRET_KEY_BASE: Generated and added (128-char hex)
- ❌ Error persists regardless of environment configuration

## Attempted Solutions
1. **Minimal Environment Configuration**: Removed all non-essential env vars - FAILED
2. **Added SECRET_KEY_BASE**: Generated 128-char hex key - FAILED
3. **Database Connection**: Verified connection to chatwoot-db-new - OK

## Comparison with Working Setup
From history file analysis (.specstory/history/2025-04-28_22-55-accessing-docker-server.md):
- Local Docker setup worked with `docker-compose up --build`
- Used environment variables: REDIS_PASSWORD, SECRET_KEY_BASE, FRONTEND_URL, POSTGRES_PASSWORD
- Local build process compiled dependencies correctly

## Current Status
- Container: chatwoot-backend-test--0000029 (Running but failing)
- Database: chatwoot-db-new (Healthy)
- API Endpoints: 502 errors due to Rails boot failure

## Recommended Next Steps
1. **Check Docker Image Build Process**: Verify Gemfile and bundle install
2. **Rebuild Docker Image**: Use local successful build process
3. **Examine Application Configuration**: Check /app/config/application.rb:9
4. **Alternative: Deploy Fresh Image**: Build new image from current codebase

## Verification Commands
```bash
# Check container logs
az containerapp logs show --name chatwoot-backend-test --resource-group SM-Test --container chatwoot-backend --tail 20

# Test API endpoints
curl -I https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/accounts
```

## Notes
- This is a Docker image build issue, not a configuration issue
- The history file shows successful local Docker development
- The Azure deployment is using a pre-built image with dependency problems

---

## ✅ RESOLUTION (2025-06-11 22:43:00)

### Solution Applied
**Switched to Official Chatwoot Docker Image**

Command used:
```bash
az containerapp update --name chatwoot-backend-test --resource-group SM-Test --container-name chatwoot-backend --image chatwoot/chatwoot:latest
```

### Results
- ✅ **Container Status**: chatwoot-backend-test--0000030 (Running successfully)
- ✅ **API Response**: HTTP 403 (authentication required) instead of 502/504 errors
- ✅ **Rails Application**: Starting successfully without gem dependency errors
- ✅ **Database Connection**: Maintained connection to chatwoot-db-new

### Verification
```bash
# API endpoint test
curl -I https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/accounts
# Result: HTTP/2 403 (application working, authentication required)

# Root endpoint test  
curl -I https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/
# Result: HTTP/2 403 (application working, authentication required)
```

### Key Learnings
1. **Custom Docker images** can have dependency issues that official images don't have
2. **Git-based gems** require proper build environment and access during Docker build
3. **Official Chatwoot image** (`chatwoot/chatwoot:latest`) has all dependencies properly compiled
4. **HTTP 403 responses** indicate successful Rails application startup (vs 502/504 server errors)

### Current Configuration
- **Image**: `chatwoot/chatwoot:latest` (official)
- **Database**: `chatwoot-db-new` (PostgreSQL 16, healthy)
- **Environment Variables**: `DATABASE_URL`, `SECRET_KEY_BASE`
- **Redis**: Sidecar container (`redis:7-alpine`)

### Next Steps
- Configure authentication/admin access
- Test full application functionality
- Consider updating KrakenD configuration if needed 