# 🛡️ Chatwoot Deployment Prevention Guide

**Preventing Docker Image Dependency Issues in Future Deployments**

## 📋 **Quick Reference**

### ✅ **What to Do**
1. **Use official images**: `chatwoot/chatwoot:latest`
2. **Validate before deploy**: Run `./scripts/validate_chatwoot_image.sh`
3. **Include required env vars**: `SECRET_KEY_BASE`, `DATABASE_URL`
4. **Test locally first**: `docker run` tests before Azure deployment
5. **Document everything**: Keep deployment records

### ❌ **What to Avoid**
1. **Custom registry images** without validation
2. **Missing environment variables** (especially `SECRET_KEY_BASE`)
3. **Deploying untested images** directly to production
4. **Unclear version tags** like "v6-final"

## 🚨 **The Problem We Solved**

### Issue
```
LoadError: cannot load such file -- devise-secure_password
```

### Root Cause
Custom Docker image `chatwootregistry95290.azurecr.io/chatwoot-full:v6-final` was missing the `devise-secure_password` gem dependency.

### Solution
Switched to official Chatwoot image: `chatwoot/chatwoot:latest`

## 🔧 **Prevention Tools**

### 1. **Image Validation Script**
```bash
# Test any image before deployment
./scripts/validate_chatwoot_image.sh chatwoot/chatwoot:latest

# Test custom images
./scripts/validate_chatwoot_image.sh your-registry/chatwoot:custom
```

### 2. **Pre-Deployment Checklist**
- [ ] Image validated with script
- [ ] SECRET_KEY_BASE generated (128-char hex)
- [ ] DATABASE_URL configured correctly
- [ ] Local Docker test passed
- [ ] Staging deployment tested
- [ ] Rollback plan documented

### 3. **Environment Variables Template**
```bash
# Required
SECRET_KEY_BASE=$(openssl rand -hex 64)
DATABASE_URL=postgresql://user:pass@host:port/database
RAILS_ENV=production

# Recommended
FRONTEND_URL=https://your-domain.com
REDIS_URL=redis://localhost:6379
RAILS_LOG_TO_STDOUT=enabled
RAILS_SERVE_STATIC_FILES=true
```

## 📊 **Deployment Workflow**

### Phase 1: Local Validation
```bash
# 1. Test image locally
./scripts/validate_chatwoot_image.sh chatwoot/chatwoot:latest

# 2. Generate environment variables
SECRET_KEY_BASE=$(openssl rand -hex 64)
echo "SECRET_KEY_BASE=$SECRET_KEY_BASE"

# 3. Test with docker-compose (if available)
docker-compose up --build
```

### Phase 2: Staging Deployment
```bash
# 1. Deploy to staging
az containerapp create \
  --name chatwoot-staging \
  --resource-group SM-Test \
  --image chatwoot/chatwoot:latest \
  --env-vars SECRET_KEY_BASE="$SECRET_KEY_BASE" \
             DATABASE_URL="$DATABASE_URL"

# 2. Validate staging
curl -I https://chatwoot-staging.azurecontainerapps.io/api/v1/accounts
# Expected: HTTP 403 (not 502/504)
```

### Phase 3: Production Deployment
```bash
# Only after staging validation passes
az containerapp update \
  --name chatwoot-backend-test \
  --resource-group SM-Test \
  --image chatwoot/chatwoot:latest
```

## 🚨 **Warning Signs**

### Image Issues
- Custom registry images without documentation
- Version tags that aren't semantic (avoid "v6-final")
- Images that haven't been updated recently
- Build processes that fail locally

### Runtime Issues
```bash
# These errors indicate problems:
LoadError: cannot load such file -- devise-secure_password
Gem::LoadError: Could not find gem
Bundle::GemNotFound
HTTP 502/504 errors from API endpoints
```

### Environment Issues
- Missing `SECRET_KEY_BASE`
- Malformed `DATABASE_URL`
- Missing `RAILS_ENV=production`

## 🔄 **Recovery Procedures**

### Immediate Fix (Emergency)
```bash
# Switch to known working image
az containerapp update \
  --name chatwoot-backend-test \
  --resource-group SM-Test \
  --container-name chatwoot-backend \
  --image chatwoot/chatwoot:latest
```

### Validation Fix
```bash
# Test the problematic image
./scripts/validate_chatwoot_image.sh problematic-image:tag

# Check specific gem
docker run --rm problematic-image:tag bundle list | grep devise-secure_password
```

## 📚 **Documentation Template**

For each deployment, document:

```yaml
deployment_record:
  date: 2025-06-11T22:45:00Z
  container: chatwoot-backend-test
  image: chatwoot/chatwoot:latest
  validation_passed: true
  environment_variables:
    - SECRET_KEY_BASE: "✅ Generated 128-char hex"
    - DATABASE_URL: "✅ Points to chatwoot-db-new"
    - RAILS_ENV: "production"
  tests_performed:
    - image_validation: "✅ PASSED"
    - local_docker_test: "✅ PASSED"
    - api_response_test: "✅ HTTP 403 (expected)"
  rollback_image: "chatwoot/chatwoot:latest"
  notes: "Switched from custom image due to devise-secure_password gem issue"
```

## 🎯 **Key Success Metrics**

### Healthy Deployment
- ✅ HTTP 403 responses (authentication required)
- ✅ Rails application starts without errors
- ✅ All required gems present
- ✅ Database connection successful

### Unhealthy Deployment
- ❌ HTTP 502/504 errors
- ❌ Gem loading errors in logs
- ❌ Rails startup failures
- ❌ Container restart loops

## 🔮 **Future Considerations**

### Image Management
1. **Pin specific versions** for production (e.g., `chatwoot/chatwoot:v3.0.0`)
2. **Regular updates** to latest stable versions
3. **Security scanning** of images before deployment
4. **Automated testing** in CI/CD pipeline

### Monitoring
1. **Health checks** for container status
2. **Log monitoring** for gem loading errors
3. **API endpoint monitoring** for response codes
4. **Database connection monitoring**

## 📞 **Emergency Contacts**

When deployment issues occur:
1. **Check this guide** for common solutions
2. **Run validation script** to identify issues
3. **Switch to official image** as immediate fix
4. **Document the incident** for future prevention

---

**Remember**: The official Chatwoot image (`chatwoot/chatwoot:latest`) is your safety net. When in doubt, use it! 