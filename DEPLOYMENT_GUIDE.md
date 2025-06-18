# Chatwoot Azure Deployment Guide

**Free CI/CD Solution using GitHub Actions + Azure Container Apps**

## 🎯 Overview

This setup provides a **completely free** continuous deployment solution for your Chatwoot application using:

- **GitHub Actions** (2,000 free minutes/month)
- **Azure Container Apps** (pay-per-use, very cost-effective)
- **Multi-environment support** (development, staging, production)
- **Automated testing and deployment**
- **Environment-specific configurations**

## 🏗️ Architecture

```
GitHub Repository
├── Push to main → Production Deployment
├── Push to develop → Staging Deployment  
└── Push to feature/* → Development Deployment

Azure Resources:
├── PostgreSQL Server: chatwoot-db-fresh
│   ├── Database: chatwoot_production (main branch)
│   ├── Database: chatwoot_staging (develop branch)
│   └── Database: chatwoot (feature branches)
├── Container Registry: chatwootregistry95290
└── Container Apps:
    ├── chatwoot-backend-prod (production)
    ├── chatwoot-backend-staging (staging)
    └── chatwoot-backend-test (development)
```

## 🚀 Quick Setup

### 1. Install Prerequisites

```bash
# Install GitHub CLI
brew install gh

# Login to GitHub
gh auth login

# Ensure Azure CLI is installed and logged in
az login
```

### 2. Configure GitHub Secrets

Run the automated setup script:

```bash
./scripts/setup_github_secrets.sh
```

This will configure all necessary secrets:
- Azure credentials
- Container registry access
- Database credentials  
- Application secrets

### 3. Create Service Principal

```bash
# Get your subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create service principal for GitHub Actions
az ad sp create-for-rbac \
  --name "chatwoot-github-actions" \
  --role contributor \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/SM-Test" \
  --sdk-auth
```

Copy the JSON output and paste it when prompted by the setup script.

## 📋 Environment Management

### List Available Environments

```bash
ruby scripts/manage_environments.rb --list
```

### Show Environment Details

```bash
ruby scripts/manage_environments.rb --show development
ruby scripts/manage_environments.rb --show staging
ruby scripts/manage_environments.rb --show production
```

### Check Deployment Status

```bash
ruby scripts/manage_environments.rb --status development
```

### Generate Environment Variables

```bash
ruby scripts/manage_environments.rb --env-vars production
```

## 🔄 Deployment Workflow

### Automatic Deployments

1. **Development**: Push to any `feature/*` branch
   - Deploys to `chatwoot-backend-test`
   - Uses `chatwoot` database
   - Debug logging enabled

2. **Staging**: Push to `develop` branch
   - Deploys to `chatwoot-backend-staging`
   - Uses `chatwoot_staging` database
   - Production-like environment

3. **Production**: Push to `main` branch
   - Deploys to `chatwoot-backend-prod`
   - Uses `chatwoot_production` database
   - Runs database migrations
   - Full production configuration

### Manual Deployment

You can also trigger deployments manually from GitHub Actions tab.

## 🗄️ Database Management

### Current Setup

- **Server**: `chatwoot-db-fresh.postgres.database.azure.com`
- **Databases**:
  - `chatwoot_production` (production)
  - `chatwoot_staging` (staging - create if needed)
  - `chatwoot` (development/testing)

### Create Staging Database

```bash
az postgres flexible-server db create \
  --server-name chatwoot-db-fresh \
  --resource-group SM-Test \
  --database-name chatwoot_staging
```

## 🔧 Configuration Files

### Environment Configuration
- `config/environments.yml` - Central environment configuration
- `.github/workflows/azure-deploy.yml` - GitHub Actions workflow
- `scripts/manage_environments.rb` - Environment management utilities

### Sidekiq Configuration
The deployment includes proper Sidekiq worker containers with weighted queue processing:

```yaml
# config/sidekiq.yml
:queues:
  - [critical, 10]
  - [high, 8] 
  - [medium, 6]
  - [default, 4]
  - [mailers, 3]
  - [low, 2]
  - [scheduled_jobs, 1]
```

## 🔐 Security Best Practices

### GitHub Secrets
All sensitive data is stored as GitHub secrets:
- `AZURE_CREDENTIALS` - Service principal JSON
- `DB_USERNAME`, `DB_PASSWORD` - Database credentials
- `SECRET_KEY_BASE` - Rails secret key
- `REDIS_URL` - Redis connection string

### Environment Variables
Each environment has isolated configuration:
- Separate databases
- Environment-specific URLs
- Feature flags per environment
- SSL enforcement in production

## 📊 Monitoring & Debugging

### View Deployment Logs

```bash
# GitHub Actions logs
gh run list
gh run view [RUN_ID]

# Container App logs
az containerapp logs show \
  --name chatwoot-backend-test \
  --resource-group SM-Test \
  --follow
```

### Health Checks

```bash
# Check container app status
az containerapp show \
  --name chatwoot-backend-test \
  --resource-group SM-Test \
  --query 'properties.runningStatus'

# Test application endpoint
curl https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/health
```

## 🆚 Alternative Solutions (Comparison)

| Solution | Cost | Complexity | Features |
|----------|------|------------|----------|
| **GitHub Actions** ✅ | Free (2000 min/month) | Low | Full CI/CD, Multi-env |
| Azure DevOps | Free (1800 min/month) | Medium | Enterprise features |
| GitLab CI | Free (400 min/month) | Medium | Integrated platform |
| Jenkins | Free (self-hosted) | High | Full control |
| Heroku | $7+/month | Low | Simple but limited |

## 🔄 Branch Strategy

```
main (production)
├── develop (staging)
│   ├── feature/user-auth
│   ├── feature/sms-integration
│   └── feature/api-improvements
└── hotfix/critical-bug (production)
```

## 🚨 Troubleshooting

### Common Issues

1. **Deployment fails with authentication error**
   ```bash
   # Refresh Azure credentials
   az login
   # Re-run setup script
   ./scripts/setup_github_secrets.sh
   ```

2. **Database connection issues**
   ```bash
   # Check database status
   az postgres flexible-server show \
     --name chatwoot-db-fresh \
     --resource-group SM-Test
   ```

3. **Container app not starting**
   ```bash
   # Check logs
   az containerapp logs show \
     --name chatwoot-backend-test \
     --resource-group SM-Test
   ```

### Debug Files
Following user rules, debug information is stored in `./debug/` folder with timestamps and symptoms for future reference.

## 📞 Support

- Check existing debug files in `./debug/` folder
- Review GitHub Actions logs
- Monitor Azure Container App logs
- Use environment management scripts for status checks

---

**🎉 You now have a professional, free CI/CD pipeline for your Chatwoot application!** 