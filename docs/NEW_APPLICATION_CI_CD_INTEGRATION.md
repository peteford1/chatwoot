# 🚀 New Application CI/CD Integration Guide

**Date**: 2025-06-18  
**Status**: Complete Integration Guide

## Overview

This guide explains how to integrate a new application with the existing Chatwoot CI/CD environment, including how to obtain and use API tokens for authentication.

## 🏗️ Current CI/CD Architecture

```
GitHub Repository (Your New App)
├── Push to main → Production Deployment
├── Push to develop → Staging Deployment  
└── Push to feature/* → Development Deployment

Azure Resources (Shared):
├── PostgreSQL Server: chatwoot-db-fresh
├── Container Registry: chatwootregistry95290
├── Container Environment: chatwoot-env-test
└── KrakenD Gateway: voicelinkai-gateway-instance-v32
```

## 📋 Prerequisites for New Application

### 1. Azure Resources (Already Available)
- ✅ **Resource Group**: `SM-Test`
- ✅ **Container Environment**: `chatwoot-env-test`
- ✅ **Container Registry**: `chatwootregistry95290.azurecr.io`
- ✅ **Database**: `chatwoot-db-fresh.postgres.database.azure.com`
- ✅ **Redis**: Available via `REDIS_URL`

### 2. Required GitHub Secrets
Your new application repository needs these secrets configured:

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `AZURE_CREDENTIALS` | Service Principal JSON | Copy from existing repo |
| `AZURE_REGISTRY_USERNAME` | Container registry username | `chatwootregistry95290` |
| `AZURE_REGISTRY_PASSWORD` | Container registry password | From Azure portal |
| `DB_HOST` | PostgreSQL hostname | `chatwoot-db-fresh.postgres.database.azure.com` |
| `DB_USERNAME` | Database username | `chatwootuser` |
| `DB_PASSWORD` | Database password | From existing secrets |
| `REDIS_URL` | Redis connection string | From existing secrets |
| `SECRET_KEY_BASE` | Rails secret key | Generate new or copy existing |

## 🔑 Chatwoot API Token Integration

### Current Token Structure
The Chatwoot environment has multiple token types:

#### **Platform Tokens** (System-wide access)
```bash
# For account/user management via Platform API
CHATWOOT_PLATFORM_TOKEN="sY484EvR8qK8hR3MZpC5Z5wV"
```

#### **User Access Tokens** (User-specific access)
```bash
# Super Admin Token (primary admin)
CHATWOOT_ADMIN_TOKEN="bb02bd4083fc907af6a7857e937af9067e1c68fde8995e90186545bb34e945f1"
CHATWOOT_ADMIN_USER_ID=1

# Store Admin Token (secondary admin)
CHATWOOT_STORE_ADMIN_TOKEN="3c1392631cabfe6c1a5cc444f47586b09fd9f0739f4fbcef01e44cd920c6e034"
CHATWOOT_STORE_ADMIN_USER_ID=3
```

#### **Account Information**
```bash
CHATWOOT_ACCOUNT_ID=2
CHATWOOT_ACCOUNT_NAME="voicelinkai"
```

### How Your Application Gets Tokens

#### Option 1: Environment-Based Token Injection
Add these environment variables to your container deployment:

```yaml
env_vars:
  # Chatwoot Integration
  CHATWOOT_API_URL: "http://voicelinkai.com/dev/api/v1"  # Development
  CHATWOOT_ADMIN_TOKEN: ${{ secrets.CHATWOOT_ADMIN_TOKEN }}
  CHATWOOT_ACCOUNT_ID: ${{ secrets.CHATWOOT_ACCOUNT_ID }}
  CHATWOOT_PLATFORM_TOKEN: ${{ secrets.CHATWOOT_PLATFORM_TOKEN }}
```

#### Option 2: Runtime Token Retrieval
Your application can retrieve tokens at runtime:

```javascript
// Example: Node.js application
const CHATWOOT_CONFIG = {
  apiUrl: process.env.CHATWOOT_API_URL,
  adminToken: process.env.CHATWOOT_ADMIN_TOKEN,
  accountId: process.env.CHATWOOT_ACCOUNT_ID,
  platformToken: process.env.CHATWOOT_PLATFORM_TOKEN
};
```

## 📁 Required Files for Your New Application

### 1. GitHub Actions Workflow
Create `.github/workflows/azure-deploy.yml`:

```yaml
name: Deploy New Application to Azure

on:
  push:
    branches:
      - main        # Production
      - develop     # Staging  
      - feature/*   # Development

env:
  AZURE_CONTAINER_REGISTRY: chatwootregistry95290.azurecr.io
  RESOURCE_GROUP: SM-Test
  CONTAINER_ENV: chatwoot-env-test

jobs:
  detect-environment:
    runs-on: ubuntu-latest
    outputs:
      environment: ${{ steps.env.outputs.environment }}
      app_name: ${{ steps.env.outputs.app_name }}
      chatwoot_api_url: ${{ steps.env.outputs.chatwoot_api_url }}
    steps:
      - name: Determine Environment
        id: env
        run: |
          if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "environment=production" >> $GITHUB_OUTPUT
            echo "app_name=your-app-prod" >> $GITHUB_OUTPUT
            echo "chatwoot_api_url=http://voicelinkai.com/prod/api/v1" >> $GITHUB_OUTPUT
          elif [[ "${{ github.ref }}" == "refs/heads/develop" ]]; then
            echo "environment=staging" >> $GITHUB_OUTPUT
            echo "app_name=your-app-staging" >> $GITHUB_OUTPUT
            echo "chatwoot_api_url=http://voicelinkai.com/staging/api/v1" >> $GITHUB_OUTPUT
          else
            echo "environment=development" >> $GITHUB_OUTPUT
            echo "app_name=your-app-dev" >> $GITHUB_OUTPUT
            echo "chatwoot_api_url=http://voicelinkai.com/dev/api/v1" >> $GITHUB_OUTPUT
          fi

  build-and-deploy:
    runs-on: ubuntu-latest
    needs: detect-environment
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Build and push Docker image
        run: |
          IMAGE_TAG=${{ env.AZURE_CONTAINER_REGISTRY }}/your-app:${{ needs.detect-environment.outputs.environment }}-${{ github.sha }}
          docker build -t $IMAGE_TAG .
          docker push $IMAGE_TAG
          echo "IMAGE_TAG=$IMAGE_TAG" >> $GITHUB_ENV

      - name: Deploy to Azure Container Apps
        run: |
          az containerapp create \
            --name ${{ needs.detect-environment.outputs.app_name }} \
            --resource-group ${{ env.RESOURCE_GROUP }} \
            --environment ${{ env.CONTAINER_ENV }} \
            --image ${{ env.IMAGE_TAG }} \
            --target-port 3000 \
            --ingress external \
            --min-replicas 1 \
            --max-replicas 3 \
            --cpu 0.5 \
            --memory 1.0Gi \
            --env-vars \
              NODE_ENV=${{ needs.detect-environment.outputs.environment }} \
              CHATWOOT_API_URL="${{ needs.detect-environment.outputs.chatwoot_api_url }}" \
              CHATWOOT_ADMIN_TOKEN="${{ secrets.CHATWOOT_ADMIN_TOKEN }}" \
              CHATWOOT_ACCOUNT_ID="${{ secrets.CHATWOOT_ACCOUNT_ID }}" \
              CHATWOOT_PLATFORM_TOKEN="${{ secrets.CHATWOOT_PLATFORM_TOKEN }}" \
              DATABASE_URL="postgresql://${{ secrets.DB_USERNAME }}:${{ secrets.DB_PASSWORD }}@${{ secrets.DB_HOST }}:5432/your_app_db" \
              REDIS_URL="${{ secrets.REDIS_URL }}"
```

### 2. Dockerfile
Create a `Dockerfile` for your application:

```dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY . .

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start application
CMD ["npm", "start"]
```

### 3. Environment Configuration
Create `config/environments.js`:

```javascript
module.exports = {
  development: {
    chatwoot: {
      apiUrl: process.env.CHATWOOT_API_URL || 'http://voicelinkai.com/dev/api/v1',
      adminToken: process.env.CHATWOOT_ADMIN_TOKEN,
      accountId: process.env.CHATWOOT_ACCOUNT_ID,
      platformToken: process.env.CHATWOOT_PLATFORM_TOKEN
    },
    database: {
      url: process.env.DATABASE_URL
    },
    redis: {
      url: process.env.REDIS_URL
    }
  },
  staging: {
    chatwoot: {
      apiUrl: process.env.CHATWOOT_API_URL || 'http://voicelinkai.com/staging/api/v1',
      adminToken: process.env.CHATWOOT_ADMIN_TOKEN,
      accountId: process.env.CHATWOOT_ACCOUNT_ID,
      platformToken: process.env.CHATWOOT_PLATFORM_TOKEN
    }
  },
  production: {
    chatwoot: {
      apiUrl: process.env.CHATWOOT_API_URL || 'http://voicelinkai.com/prod/api/v1',
      adminToken: process.env.CHATWOOT_ADMIN_TOKEN,
      accountId: process.env.CHATWOOT_ACCOUNT_ID,
      platformToken: process.env.CHATWOOT_PLATFORM_TOKEN
    }
  }
};
```

## 🔐 Setting Up GitHub Secrets

### Method 1: Manual Setup
1. Go to your new repository
2. Navigate to `Settings > Secrets and variables > Actions`
3. Add each required secret from the table above

### Method 2: Automated Setup (Recommended)
Create `scripts/setup_github_secrets.sh`:

```bash
#!/bin/bash

# GitHub repository (update this)
GITHUB_REPO="your-org/your-new-app"

# Set GitHub secrets
gh secret set AZURE_CREDENTIALS --body "$(cat azure-credentials.json)" --repo $GITHUB_REPO
gh secret set AZURE_REGISTRY_USERNAME --body "chatwootregistry95290" --repo $GITHUB_REPO
gh secret set AZURE_REGISTRY_PASSWORD --body "$AZURE_REGISTRY_PASSWORD" --repo $GITHUB_REPO
gh secret set DB_HOST --body "chatwoot-db-fresh.postgres.database.azure.com" --repo $GITHUB_REPO
gh secret set DB_USERNAME --body "chatwootuser" --repo $GITHUB_REPO
gh secret set DB_PASSWORD --body "$DB_PASSWORD" --repo $GITHUB_REPO
gh secret set REDIS_URL --body "$REDIS_URL" --repo $GITHUB_REPO
gh secret set SECRET_KEY_BASE --body "$(openssl rand -hex 64)" --repo $GITHUB_REPO

# Chatwoot-specific secrets
gh secret set CHATWOOT_ADMIN_TOKEN --body "bb02bd4083fc907af6a7857e937af9067e1c68fde8995e90186545bb34e945f1" --repo $GITHUB_REPO
gh secret set CHATWOOT_ACCOUNT_ID --body "2" --repo $GITHUB_REPO
gh secret set CHATWOOT_PLATFORM_TOKEN --body "sY484EvR8qK8hR3MZpC5Z5wV" --repo $GITHUB_REPO

echo "✅ GitHub secrets configured for $GITHUB_REPO"
```

## 🌐 API Integration Examples

### Example 1: Creating a Conversation
```javascript
const axios = require('axios');

async function createConversation(contactId, message) {
  const response = await axios.post(
    `${process.env.CHATWOOT_API_URL}/accounts/${process.env.CHATWOOT_ACCOUNT_ID}/conversations`,
    {
      contact_id: contactId,
      inbox_id: 1, // Your inbox ID
      message: {
        content: message,
        message_type: 'outgoing'
      }
    },
    {
      headers: {
        'api_access_token': process.env.CHATWOOT_ADMIN_TOKEN,
        'Content-Type': 'application/json'
      }
    }
  );
  
  return response.data;
}
```

### Example 2: Getting Account Information
```javascript
async function getAccountInfo() {
  const response = await axios.get(
    `${process.env.CHATWOOT_API_URL}/accounts/${process.env.CHATWOOT_ACCOUNT_ID}`,
    {
      headers: {
        'api_access_token': process.env.CHATWOOT_ADMIN_TOKEN
      }
    }
  );
  
  return response.data;
}
```

### Example 3: Platform API Usage
```javascript
async function createUser(userData) {
  const response = await axios.post(
    `http://voicelinkai.com/platform/api/v1/accounts/${process.env.CHATWOOT_ACCOUNT_ID}/users`,
    userData,
    {
      headers: {
        'api_access_token': process.env.CHATWOOT_PLATFORM_TOKEN,
        'Content-Type': 'application/json'
      }
    }
  );
  
  return response.data;
}
```

## 📊 Environment-Specific Routing

Your application will automatically route to the correct Chatwoot environment:

| Your App Environment | Chatwoot API Endpoint | Backend |
|---------------------|----------------------|---------|
| **Development** | `http://voicelinkai.com/dev/api/v1` | `chatwoot-test` |
| **Staging** | `http://voicelinkai.com/staging/api/v1` | `chatwoot-staging` (pending) |
| **Production** | `http://voicelinkai.com/prod/api/v1` | `chatwoot-production` (pending) |

## 🚀 Deployment Process

### 1. Initial Setup
```bash
# Clone your new app repository
git clone https://github.com/your-org/your-new-app.git
cd your-new-app

# Set up GitHub secrets
./scripts/setup_github_secrets.sh

# Create initial commit with CI/CD files
git add .github/workflows/azure-deploy.yml
git add Dockerfile
git add config/environments.js
git commit -m "Add CI/CD configuration"
git push origin main
```

### 2. Development Workflow
```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes
# ... your development work ...

# Push to trigger development deployment
git push origin feature/new-feature
```

### 3. Production Deployment
```bash
# Merge to main for production deployment
git checkout main
git merge develop
git push origin main
```

## 🔍 Testing Integration

### Test Chatwoot API Connection
Create `test/chatwoot-integration.test.js`:

```javascript
const axios = require('axios');

describe('Chatwoot Integration', () => {
  test('should connect to Chatwoot API', async () => {
    const response = await axios.get(
      `${process.env.CHATWOOT_API_URL}/accounts/${process.env.CHATWOOT_ACCOUNT_ID}`,
      {
        headers: {
          'api_access_token': process.env.CHATWOOT_ADMIN_TOKEN
        }
      }
    );
    
    expect(response.status).toBe(200);
    expect(response.data.id).toBe(parseInt(process.env.CHATWOOT_ACCOUNT_ID));
  });
});
```

## 📚 Additional Resources

### Current Token Files (For Reference)
- `voicelinkai_test_deployment_tokens_1750114021.env` - Current active tokens
- `chatwoot_tokens.env` - Development environment tokens
- `azure_database_config.env` - Database configuration

### Existing Scripts (You Can Reuse)
- `scripts/manage_environments.rb` - Environment management
- `scripts/deployment_seeder.rb` - Account/user creation
- `scripts/validate_environment.rb` - Environment validation

### Documentation
- `docs/AUTOMATED_DEPLOYMENT.md` - Deployment automation guide
- `docs/ENVIRONMENT_RESTRUCTURE_SUMMARY.md` - Environment structure
- `DEPLOYMENT_GUIDE.md` - General deployment guide

## ⚠️ Important Notes

### Security
- ✅ **Never commit tokens to git** - Always use GitHub secrets
- ✅ **Use environment-specific tokens** - Different tokens for dev/staging/prod
- ✅ **Rotate tokens regularly** - Especially for production

### Database Access
- ✅ **Shared PostgreSQL server** - All apps use `chatwoot-db-fresh`
- ✅ **Separate databases** - Each app gets its own database
- ✅ **Schema isolation** - Use different schemas if sharing databases

### Networking
- ✅ **Internal communication** - Apps can communicate via container names
- ✅ **External access** - All apps get public URLs via Azure Container Apps
- ✅ **KrakenD routing** - API calls route through the gateway

## 🎯 Next Steps

1. **Create your new application repository**
2. **Copy the CI/CD configuration files** from this guide
3. **Set up GitHub secrets** using the provided script
4. **Test the deployment** by pushing to a feature branch
5. **Verify Chatwoot integration** using the test examples
6. **Deploy to production** when ready

Your new application will automatically integrate with the existing Chatwoot environment and use the established CI/CD pipeline for seamless deployments across all environments! 