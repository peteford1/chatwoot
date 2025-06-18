# Automated Chatwoot Deployment on Azure

This document explains how to use the automated GitHub Actions workflow to deploy Chatwoot to Azure Container Apps.

## Overview

The automated deployment workflow reproduces all the successful manual steps we performed:

1. **Database Preparation**: Automatically runs `rails db:chatwoot_prepare` if needed
2. **Container Deployment**: Creates Azure Container App with proper configuration
3. **Environment Setup**: Configures all required environment variables
4. **Health Checks**: Tests deployment and provides status reports

## Prerequisites

### Azure Resources Required

Before running the workflow, ensure these Azure resources exist:

- **Resource Group**: `SM-Test` (or update workflow to match yours)
- **PostgreSQL Flexible Server**: `chatwoot-db-fresh`
- **Redis Cache**: `chatwoot-redis`
- **Container Apps Environment**: `chatwoot-env-test`

### GitHub Secrets Required

Set up these secrets in your GitHub repository (`Settings > Secrets and variables > Actions`):

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AZURE_CREDENTIALS` | Service Principal JSON | `{"clientId":"...","clientSecret":"...","subscriptionId":"...","tenantId":"..."}` |
| `DB_HOST` | PostgreSQL server hostname | `chatwoot-db-fresh.postgres.database.azure.com` |
| `DB_USERNAME` | PostgreSQL username | `chatwootuser` |
| `DB_PASSWORD` | PostgreSQL password | `Sunnymead123!` |
| `SECRET_KEY_BASE` | Rails secret key | `supersecretkeybasefortest123456789abcdefghijklmnopqrstuvwxyz` |
| `REDIS_URL` | Redis connection string | `rediss://default:PASSWORD@chatwoot-redis.redis.cache.windows.net:6380` |

## How to Use the Workflow

### 1. Manual Trigger

1. Go to your GitHub repository
2. Click on **Actions** tab
3. Select **Deploy Chatwoot to Azure Container Apps**
4. Click **Run workflow**
5. Fill in the parameters:
   - **Environment**: Choose `test`, `staging`, or `production`
   - **Container Name**: Enter a unique name (e.g., `chatwoot-automated-v1`)

### 2. Workflow Parameters

- **environment**: Target deployment environment
- **container_name**: Name for the Azure Container App (must be unique)

## Workflow Stages

### Stage 1: Database Preparation

- ✅ Checks out the code
- ✅ Sets up Ruby environment
- ✅ Tests database connectivity
- ✅ Checks if database is already prepared (counts tables)
- ✅ Runs `rails db:chatwoot_prepare` only if needed
- ✅ Verifies successful preparation

### Stage 2: Container Deployment

- ✅ Deletes existing container if it exists
- ✅ Creates new Azure Container App
- ✅ Configures all environment variables
- ✅ Uses official `chatwoot/chatwoot:latest` image
- ✅ Sets up external ingress on port 3000

### Stage 3: Post-Deployment

- ✅ Tests deployment endpoints
- ✅ Shows container logs
- ✅ Creates deployment record
- ✅ Provides next steps

## Environment Variables Configured

The workflow automatically sets these environment variables:

```yaml
RAILS_ENV: production
SECRET_KEY_BASE: # From GitHub secret
POSTGRES_HOST: # From GitHub secret
POSTGRES_USERNAME: # From GitHub secret
POSTGRES_PASSWORD: # From GitHub secret
POSTGRES_DATABASE: chatwoot_shared
POSTGRES_PORT: 5432
REDIS_URL: # From GitHub secret
FRONTEND_URL: # Auto-generated based on container name
ACTIVE_STORAGE_SERVICE: local
RAILS_LOG_TO_STDOUT: true
RAILS_SERVE_STATIC_FILES: true
MAILER_SENDER_EMAIL: admin@voicelinkai.com
INSTALLATION_NAME: "VoiceLink AI Chatwoot"
ENABLE_ACCOUNT_SIGNUP: false
```

## Customization

### Different Environments

To deploy to different environments, update these values in the workflow:

```yaml
env:
  RESOURCE_GROUP: SM-Test          # Change for different resource groups
  LOCATION: eastus                 # Change for different regions
  CONTAINER_ENV: chatwoot-env-test # Change for different environments
```

### Different Container Settings

Modify the container creation parameters:

```yaml
--min-replicas 1 \      # Minimum instances
--max-replicas 2 \      # Maximum instances
--cpu 1.0 \            # CPU allocation
--memory 2.0Gi \       # Memory allocation
```

### Additional Environment Variables

Add more environment variables in the `--env-vars` section:

```yaml
--env-vars \
  # ... existing variables ...
  YOUR_CUSTOM_VAR="value" \
  ANOTHER_VAR="${{ secrets.ANOTHER_SECRET }}"
```

## Troubleshooting

### Common Issues

1. **Database Connection Failed**
   - Verify `DB_HOST`, `DB_USERNAME`, `DB_PASSWORD` secrets
   - Check PostgreSQL firewall rules
   - Ensure database `chatwoot_shared` exists

2. **Container Creation Failed**
   - Verify `AZURE_CREDENTIALS` secret
   - Check Azure Container Apps Environment exists
   - Ensure container name is unique

3. **Application Not Responding**
   - Check container logs in Azure portal
   - Verify Redis connection string
   - Ensure all required environment variables are set

### Debugging Steps

1. **Check GitHub Actions logs** for detailed error messages
2. **Review Azure Container Apps logs** in Azure portal
3. **Verify secrets** are correctly set in GitHub
4. **Test database connection** manually using Azure CLI

## Success Criteria

The deployment is successful when:

- ✅ Database has 77+ tables
- ✅ Container is in "Running" status
- ✅ Application responds to HTTP requests
- ✅ No errors in container logs

## Next Steps After Deployment

1. **Access the application** at the provided URL
2. **Set up admin user** through the web interface
3. **Configure additional settings** as needed
4. **Set up monitoring** and alerts
5. **Configure custom domain** if required

## Rollback Strategy

To rollback a deployment:

1. Run the workflow again with a previous working container name
2. Or manually restore from a backup using Azure CLI
3. Database changes are persistent and may need manual rollback

## Security Considerations

- All secrets are stored securely in GitHub Secrets
- Database credentials are not logged
- Container environment variables are encrypted at rest
- Network traffic uses HTTPS/TLS encryption

## Monitoring

After deployment, monitor:

- **Container health** in Azure Container Apps
- **Database performance** in Azure PostgreSQL
- **Redis performance** in Azure Cache for Redis
- **Application logs** for errors or warnings 