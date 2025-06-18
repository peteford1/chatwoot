# Chatwoot Deployment Best Practices

**Date:** 2025-06-11 22:45:00
**Purpose:** Prevent Docker image dependency issues in future deployments

## 🎯 **Core Principles**

### 1. **Always Use Official Images First**
```bash
# ✅ RECOMMENDED: Official Chatwoot image
az containerapp update --name chatwoot-backend-test --resource-group SM-Test --container-name chatwoot-backend --image chatwoot/chatwoot:latest

# ❌ AVOID: Custom/unknown registry images
# chatwootregistry95290.azurecr.io/chatwoot-full:v6-final
```

**Why:** Official images are:
- Regularly maintained and tested
- Have all dependencies properly compiled
- Include security updates
- Follow best practices for gem installation

### 2. **Image Validation Process**
Before deploying any Docker image, validate it locally:

```bash
# Test image locally first
docker run --rm -it chatwoot/chatwoot:latest bundle exec rails --version

# Check for specific gem dependencies
docker run --rm -it chatwoot/chatwoot:latest bundle list | grep devise

# Verify Rails can start
docker run --rm -e SECRET_KEY_BASE=test123 chatwoot/chatwoot:latest bundle exec rails runner "puts 'Rails OK'"
```

### 3. **Environment Variable Management**
Always include these essential environment variables:

```bash
# Required for Rails applications
SECRET_KEY_BASE=<128-character-hex-string>
DATABASE_URL=postgresql://user:pass@host:port/database
RAILS_ENV=production

# Chatwoot-specific
FRONTEND_URL=https://your-domain.com
REDIS_URL=redis://localhost:6379

# Optional but recommended
RAILS_LOG_TO_STDOUT=enabled
RAILS_SERVE_STATIC_FILES=true
```

### 4. **Custom Image Build Guidelines**
If you must build custom images:

```dockerfile
# Use official Ruby base image
FROM ruby:3.3.3-alpine3.19

# Install Git for Git-based gems
RUN apk add --no-cache git build-base postgresql-dev

# Copy Gemfile first for better caching
COPY Gemfile Gemfile.lock ./

# Install gems with proper Git access
RUN bundle config set --local force_ruby_platform true
RUN bundle install --jobs 4 --retry 3

# Verify critical gems are installed
RUN bundle exec ruby -e "require 'devise-secure_password'; puts 'Gem OK'"
```

## 🔍 **Testing & Validation**

### Pre-Deployment Checklist
```bash
# 1. Test image locally
docker run --rm chatwoot/chatwoot:latest bundle exec rails --version

# 2. Check gem dependencies
docker run --rm chatwoot/chatwoot:latest bundle list | grep -E "(devise|rails)"

# 3. Test Rails startup
docker run --rm -e SECRET_KEY_BASE=test123 -e DATABASE_URL=postgresql://test chatwoot/chatwoot:latest bundle exec rails runner "puts Rails.env"

# 4. Verify API endpoints (if possible)
curl -I http://localhost:3000/api/v1/accounts
```

### Automated Validation Script
```bash
#!/bin/bash
# validate_chatwoot_image.sh

IMAGE=${1:-chatwoot/chatwoot:latest}
echo "Validating image: $IMAGE"

# Test 1: Check if image exists
if ! docker pull $IMAGE; then
    echo "❌ Image not found or inaccessible"
    exit 1
fi

# Test 2: Check Ruby version
RUBY_VERSION=$(docker run --rm $IMAGE ruby --version)
echo "✅ Ruby: $RUBY_VERSION"

# Test 3: Check Rails version
RAILS_VERSION=$(docker run --rm $IMAGE bundle exec rails --version)
echo "✅ Rails: $RAILS_VERSION"

# Test 4: Check critical gems
if docker run --rm $IMAGE bundle list | grep -q "devise-secure_password"; then
    echo "✅ devise-secure_password gem found"
else
    echo "❌ devise-secure_password gem missing"
    exit 1
fi

# Test 5: Test Rails startup
if docker run --rm -e SECRET_KEY_BASE=test123 $IMAGE bundle exec rails runner "puts 'OK'" | grep -q "OK"; then
    echo "✅ Rails startup successful"
else
    echo "❌ Rails startup failed"
    exit 1
fi

echo "🎉 Image validation passed!"
```

## 📋 **Deployment Workflow**

### 1. **Development Phase**
```bash
# Use docker-compose for local development
docker-compose up --build

# Test with official image
docker-compose -f docker-compose.production.yml up
```

### 2. **Staging Phase**
```bash
# Deploy to staging with official image
az containerapp create \
  --name chatwoot-staging \
  --resource-group SM-Test \
  --image chatwoot/chatwoot:latest \
  --environment chatwoot-env-test

# Validate staging deployment
curl -I https://chatwoot-staging.azurecontainerapps.io/api/v1/accounts
```

### 3. **Production Phase**
```bash
# Only deploy to production after staging validation
az containerapp update \
  --name chatwoot-backend-test \
  --resource-group SM-Test \
  --image chatwoot/chatwoot:latest
```

## 🚨 **Red Flags to Watch For**

### Image-Related Warning Signs
- Custom registry images without documentation
- Images with version tags like "v6-final" (unclear versioning)
- Images that haven't been updated recently
- Missing or incomplete Dockerfile

### Runtime Warning Signs
```bash
# These errors indicate image problems:
LoadError: cannot load such file -- devise-secure_password
Gem::LoadError: Could not find gem
Bundle::GemNotFound
```

### Environment Warning Signs
- Missing SECRET_KEY_BASE
- Incorrect DATABASE_URL format
- Missing RAILS_ENV in production

## 🔧 **Recovery Procedures**

### Quick Fix (Immediate)
```bash
# Switch to official image immediately
az containerapp update \
  --name chatwoot-backend-test \
  --resource-group SM-Test \
  --container-name chatwoot-backend \
  --image chatwoot/chatwoot:latest
```

### Long-term Fix (Custom Images)
1. **Audit Dockerfile**: Check gem installation process
2. **Test Build Process**: Ensure Git access during build
3. **Validate Dependencies**: Verify all gems install correctly
4. **Document Changes**: Record any customizations needed

## 📚 **Documentation Requirements**

### For Each Deployment
Document:
- Image source and version
- Environment variables used
- Any customizations made
- Validation tests performed
- Rollback procedures

### Example Documentation
```yaml
deployment:
  name: chatwoot-backend-test
  image: chatwoot/chatwoot:latest
  validated: 2025-06-11T22:45:00Z
  environment:
    - DATABASE_URL: postgresql://chatwootuser:***@chatwoot-db-new.postgres.database.azure.com/chatwoot
    - SECRET_KEY_BASE: be8769085ff68de79fd99287d2b86aad43ad0090f2af9cb56c9ebe552784037e43183d0a06d189b209cf4d481302feb2573badedfcfca2d56183b1b102d81090
  tests_passed:
    - image_pull: ✅
    - gem_dependencies: ✅
    - rails_startup: ✅
    - api_response: ✅ (HTTP 403)
```

## 🎯 **Key Takeaways**

1. **Official images first** - Always try official images before custom builds
2. **Test locally** - Validate images on your development machine
3. **Document everything** - Keep records of what works and what doesn't
4. **Automate validation** - Use scripts to check image health
5. **Plan rollbacks** - Always have a working image to fall back to

Following these practices will prevent the `devise-secure_password` gem dependency issue and similar problems in future deployments. 