# KrakenD Gateway Setup Guide

## 🌐 Overview

This guide covers the setup and deployment of KrakenD API Gateway with environment-specific configurations for the Chatwoot application.

## 📁 Directory Structure

```
krakend/
├── Dockerfile                    # Custom KrakenD image with environment support
└── environments/
    ├── dev/
    │   └── krakend.json          # Development configuration
    ├── test/
    │   └── krakend.json          # Test environment configuration
    ├── staging/
    │   └── krakend.json          # Staging configuration (to be created)
    └── prod/
        └── krakend.json          # Production configuration (to be created)
```

## 🚀 GitHub Actions Deployment

### Workflow: `Deploy KrakenD Gateway`

**Location**: `.github/workflows/deploy-krakend-gateway.yml`

**Purpose**: Builds and deploys environment-specific KrakenD gateway instances

### How to Deploy

1. **Go to GitHub Actions** in your repository
2. **Select "Deploy KrakenD Gateway"** workflow
3. **Click "Run workflow"**
4. **Fill in parameters**:
   - **Environment**: Choose `dev`, `test`, `staging`, or `prod`
   - **Gateway Name**: Container name (default: `voicelinkai-gateway`)
   - **Backend URL**: Optional override for Chatwoot backend URL

### Environment Mappings

| Environment | Default Backend URL | Container Name | Purpose |
|-------------|-------------------|----------------|---------|
| `dev` | `http://localhost:3000` | `{gateway_name}-dev` | Local development |
| `test` | `https://chatwoot-working.calmmushroom-30b1c815.eastus.azurecontainerapps.io` | `{gateway_name}-test` | Testing with current working instance |
| `staging` | `https://chatwoot-staging.calmmushroom-30b1c815.eastus.azurecontainerapps.io` | `{gateway_name}-staging` | Staging environment |
| `prod` | `https://chatwoot-prod.calmmushroom-30b1c815.eastus.azurecontainerapps.io` | `{gateway_name}-prod` | Production environment |

## 🔧 Configuration Details

### Test Environment Configuration

**File**: `krakend/environments/test/krakend.json`

**Features**:
- ✅ Points to `chatwoot-working` container
- ✅ CORS configured for Azure Container Apps domains
- ✅ Comprehensive API endpoint coverage
- ✅ Health and status endpoints
- ✅ Widget API support
- ✅ Account and conversation management

**Key Endpoints**:
- `/health` - Gateway health check
- `/api` - API information
- `/api/v1/accounts/{account_id}/conversations` - Conversation management
- `/api/v1/accounts/{account_id}/inboxes` - Inbox management
- `/api/v1/widget/*` - Widget API endpoints
- `/api/v1/accounts/{account_id}/search/messages` - Message search

### CORS Configuration

```json
"security/cors": {
  "allow_origins": [
    "https://chatwoot-working.calmmushroom-30b1c815.eastus.azurecontainerapps.io",
    "https://*.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
  ],
  "allow_methods": ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
  "allow_headers": [
    "Content-Type", "Authorization", "X-User-ID", "X-User-Role",
    "X-Website-Token", "User-Agent", "Origin", "Accept"
  ],
  "allow_credentials": true,
  "max_age": "12h"
}
```

## 🐳 Docker Image

### Custom KrakenD Image

**Features**:
- ✅ Multi-environment support
- ✅ Dynamic backend URL replacement
- ✅ Environment variable configuration
- ✅ Automatic configuration selection

**Environment Variables**:
- `KRAKEND_ENVIRONMENT` - Target environment (dev/test/staging/prod)
- `KRAKEND_BACKEND_URL` - Override backend URL

### Image Build Process

1. **Copies all environment configurations** to `/etc/krakend/environments/`
2. **Creates startup script** for dynamic configuration selection
3. **Supports runtime backend URL replacement**
4. **Pushed to Azure Container Registry**: `voicelinkregistry.azurecr.io/krakend-gateway`

## 🎯 Deployment Process

### Automated Steps

1. **Checkout Code** - Gets latest configurations
2. **Azure Login** - Authenticates with Azure
3. **ACR Login** - Logs into Azure Container Registry
4. **Set Environment Variables** - Configures deployment parameters
5. **Build Docker Image** - Creates custom KrakenD image
6. **Push to Registry** - Uploads image to ACR
7. **Delete Existing Gateway** - Removes old container (if exists)
8. **Deploy New Gateway** - Creates new container app
9. **Health Check** - Verifies deployment
10. **Deployment Summary** - Provides access URLs and next steps

### Deployment Output

```
🚀 KrakenD Gateway Deployment Complete!
📍 Container: voicelinkai-gateway-test
🌐 Gateway URL: https://voicelinkai-gateway-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io
🎯 Environment: test
🔗 Backend: https://chatwoot-working.calmmushroom-30b1c815.eastus.azurecontainerapps.io

🔍 Test endpoints:
   Health: https://voicelinkai-gateway-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/health
   API Info: https://voicelinkai-gateway-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api
```

## 🧪 Testing the Gateway

### Health Check

```bash
curl https://your-gateway-url.calmmushroom-30b1c815.eastus.azurecontainerapps.io/health
```

**Expected Response**:
```json
{
  "status": "ok",
  "service": "krakend-gateway-test",
  "environment": "test",
  "backend": "chatwoot-working",
  "timestamp": "2025-06-18T07:30:00Z"
}
```

### API Information

```bash
curl https://your-gateway-url.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api
```

### Chatwoot API Through Gateway

```bash
# Test conversation endpoint (requires authentication)
curl -H "Authorization: Bearer YOUR_TOKEN" \
     https://your-gateway-url.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/accounts/1/conversations
```

## 🔐 Authentication

The gateway passes through all authentication headers to the Chatwoot backend:

- `Authorization` - Bearer tokens
- `X-User-ID` - User identification
- `X-User-Role` - User role information
- `X-Website-Token` - Widget authentication

## 🌍 Environment-Specific Usage

### Test Environment

**Use Case**: Testing with the current working Chatwoot instance
**Backend**: `chatwoot-working` container
**Gateway URL**: `https://voicelinkai-gateway-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io`

### Development Environment

**Use Case**: Local development with localhost Chatwoot
**Backend**: `http://localhost:3000`
**Gateway URL**: `https://voicelinkai-gateway-dev.calmmushroom-30b1c815.eastus.azurecontainerapps.io`

## 📊 Benefits

### 🔒 Security
- Centralized authentication
- CORS management
- Request/response filtering

### ⚡ Performance
- Response caching
- Request aggregation
- Load balancing

### 🛠️ Management
- Environment isolation
- Configuration centralization
- Easy deployment switching

### 📈 Monitoring
- Request logging
- Health monitoring
- Performance metrics

## 🚨 Troubleshooting

### Common Issues

1. **Gateway returns 404**
   - Check if the endpoint is configured in the environment's `krakend.json`
   - Verify the backend URL is correct

2. **CORS errors**
   - Ensure your frontend domain is in the `allow_origins` list
   - Check if the request includes required headers

3. **Backend connection fails**
   - Verify the Chatwoot backend is running
   - Check if the backend URL is accessible

4. **Container fails to start**
   - Check Azure Container Apps logs
   - Verify the Docker image was built correctly
   - Ensure environment variables are set

### Debug Commands

```bash
# Check container status
az containerapp show --name voicelinkai-gateway-test --resource-group SM-Test

# View container logs
az containerapp logs show --name voicelinkai-gateway-test --resource-group SM-Test --follow

# Test gateway directly
curl -v https://your-gateway-url/health
```

## 🔄 Updates and Maintenance

### Adding New Endpoints

1. **Edit the environment configuration** (`krakend/environments/{env}/krakend.json`)
2. **Add the new endpoint** to the `endpoints` array
3. **Commit and push** changes
4. **Run the deployment workflow** to update the gateway

### Updating Backend URLs

1. **Option 1**: Update the configuration file and redeploy
2. **Option 2**: Use the `chatwoot_backend_url` parameter in the workflow
3. **Option 3**: Set `KRAKEND_BACKEND_URL` environment variable

### Environment Management

- **Dev**: For local development and testing
- **Test**: For integration testing with deployed instances
- **Staging**: For pre-production testing (to be configured)
- **Prod**: For production traffic (to be configured)

## 📚 Next Steps

1. **Deploy Test Gateway**: Run the workflow with `test` environment
2. **Test All Endpoints**: Verify gateway functionality
3. **Configure Staging**: Create staging environment configuration
4. **Set Up Production**: Create production environment configuration
5. **Monitor Performance**: Set up logging and monitoring
6. **Implement Rate Limiting**: Add rate limiting rules as needed

---

**🎉 Result**: Complete environment-based KrakenD gateway setup with automated deployment through GitHub Actions! 