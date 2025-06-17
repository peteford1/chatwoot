# Environment Setup Guide

This guide covers the comprehensive environment setup and seeding system for Chatwoot with proper environment isolation.

## 🎯 Overview

The environment setup system provides:
- **Environment Isolation**: Separate database schemas for development, test, staging, and production
- **Repeatable Deployments**: Consistent setup across all environments
- **Multiple Execution Methods**: GitHub Actions workflow + local scripts
- **Container Exec Workarounds**: External API seeding when container exec fails
- **Comprehensive Validation**: Status checking and verification

## 🚀 Quick Start

### Option 1: GitHub Actions (Recommended)

1. **Navigate to your fork**: https://github.com/peteford1/chatwoot/actions
2. **Select "Environment Setup and Seeding" workflow**
3. **Click "Run workflow"**
4. **Choose parameters**:
   - Environment: `test` (for VoiceLinkAI)
   - Action: `setup`
5. **Click "Run workflow"**

### Option 2: Local Script

```bash
# Set required environment variables
export DB_USERNAME="your_db_username"
export DB_PASSWORD="your_db_password"  
export DB_HOST="your_db_host"

# Run environment setup
ruby scripts/setup_environment.rb test setup
```

## 📋 Environment Configuration

Environments are configured in `config/environments.yml`:

```yaml
environments:
  development:
    database_name: "chatwoot_shared"
    database_schema: "development"
    container_app_name: "chatwoot-backend-dev"
    rails_env: "development"

  test:
    database_name: "chatwoot_shared"
    database_schema: "test"
    container_app_name: "chatwoot-backend-test"
    rails_env: "test"

  staging:
    database_name: "chatwoot_shared"
    database_schema: "staging"
    container_app_name: "chatwoot-backend-staging"
    rails_env: "staging"

  production:
    database_name: "chatwoot_production"
    database_schema: "public"
    container_app_name: "chatwoot-backend-prod"
    rails_env: "production"
```

## 🔧 Available Actions

### 1. **setup** - Full Environment Setup
- Updates container environment variables
- Runs database migrations (if container exec works)
- Seeds environment with VoiceLinkAI data
- Verifies setup completion

### 2. **status** - Environment Status Check
- Checks container status
- Tests environment accessibility
- Validates API endpoints
- Reports configuration

### 3. **seed** - Environment Seeding Only
- Creates VoiceLinkAI test data
- Platform App, Account, User setup
- Generates API tokens

### 4. **migrate** - Database Migrations Only
- Runs Rails database migrations
- Updates schema for environment

### 5. **reset** - Full Environment Reset
- Drops and recreates database schema
- Runs migrations and seeding
- **⚠️ Destructive operation**

## 🎛️ GitHub Actions Workflow

### Workflow Features:
- **Environment Detection**: Automatically loads configuration
- **Container Management**: Updates environment variables
- **Database Operations**: Migrations and seeding
- **Verification**: Comprehensive status checking
- **Error Handling**: Graceful failure handling

### Workflow Inputs:
```yaml
environment: [development, test, staging, production]
action: [setup, migrate, seed, reset, status]
```

### Usage Examples:

#### Setup Test Environment for VoiceLinkAI:
```yaml
environment: test
action: setup
```

#### Check Staging Environment Status:
```yaml
environment: staging
action: status
```

#### Reset Development Environment:
```yaml
environment: development
action: reset
```

## 🖥️ Local Script Usage

### Prerequisites:
```bash
# Required environment variables
export DB_USERNAME="chatwootuser"
export DB_PASSWORD="your_password"
export DB_HOST="chatwoot-db-fresh.postgres.database.azure.com"

# Azure CLI authentication
az login
```

### Commands:

#### Check Environment Status:
```bash
ruby scripts/setup_environment.rb test status
```

#### Setup Complete Environment:
```bash
ruby scripts/setup_environment.rb test setup
```

#### Seed Environment Only:
```bash
ruby scripts/setup_environment.rb test seed
```

## 🔍 Environment Isolation Details

### Database Schema Isolation:
- **Shared Database**: `chatwoot_shared` for dev/test/staging
- **Separate Schemas**: Each environment has isolated schema
- **Production Database**: Separate `chatwoot_production` database
- **User Isolation**: Environment-specific database users

### Container Environment Variables:
```bash
# Test Environment Example
RAILS_ENV=test
DATABASE_URL=postgresql://chatwoot_test:password@host:5432/chatwoot_shared?options=-csearch_path%3Dtest
FRONTEND_URL=https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io
```

## 🐛 Troubleshooting

### Container Exec Issues:
If Azure Container Apps exec fails with websocket errors:

1. **Use GitHub Actions**: More reliable than local exec
2. **External Seeding**: Fallback to API-based seeding
3. **Container Restart**: May resolve temporary issues

### Database Connection Issues:
1. **Check Environment Variables**: Verify DATABASE_URL format
2. **Schema Permissions**: Ensure user has schema access
3. **Network Connectivity**: Test database accessibility

### API Endpoint 404 Errors:
1. **Run Migrations**: Database schema may be empty
2. **Check Rails Environment**: Verify RAILS_ENV setting
3. **Container Restart**: Environment variables may not be loaded

## 📊 Verification and Validation

### Automatic Checks:
- ✅ Container accessibility
- ✅ API endpoint availability
- ✅ Database connectivity
- ✅ Environment configuration

### Manual Verification:
```bash
# Test environment accessibility
curl https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/

# Test API endpoints (should return 401 - auth required)
curl https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/accounts
curl https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile
```

## 🎯 VoiceLinkAI Integration

### Generated Resources:
After successful seeding, you'll receive:

- **Platform Token**: For Platform API access
- **Admin Token**: For Application API access
- **Account ID**: VoiceLinkAI account identifier
- **User ID**: Admin user identifier

### API Endpoints:
```bash
# Platform API
https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/

# Application API
https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/
```

### Test Integration:
```bash
# Using Platform Token
curl -H "api_access_token: YOUR_PLATFORM_TOKEN" \
  https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/accounts

# Using Admin Token
curl -H "api_access_token: YOUR_ADMIN_TOKEN" \
  https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile
```

## 🔄 Maintenance

### Regular Tasks:
1. **Monitor Environment Health**: Use status checks
2. **Update Container Images**: Through CI/CD pipeline
3. **Database Maintenance**: Schema updates and backups
4. **Token Rotation**: Regenerate API tokens periodically

### Environment Updates:
```bash
# Update environment configuration
vim config/environments.yml

# Apply changes via GitHub Actions
git commit -am "Update environment configuration"
git push fork voicelinkai-seeder-deploy
```

## 📚 Related Files

- **Workflow**: `.github/workflows/environment-setup.yml`
- **Local Script**: `scripts/setup_environment.rb`
- **Configuration**: `config/environments.yml`
- **External Seeder**: `external_test_seeder.rb`
- **Environment Diagnosis**: `fix_test_environment.rb`

## 🚨 Important Notes

1. **Production Safety**: Reset action is disabled for production
2. **Environment Variables**: Use GitHub secrets for sensitive data
3. **Container Exec**: May fail due to Azure infrastructure issues
4. **API Fallbacks**: External seeding provides reliable alternative
5. **Schema Isolation**: Each environment is completely isolated

---

**🎉 Your environment setup system is now fully automated and repeatable across all environments!** 