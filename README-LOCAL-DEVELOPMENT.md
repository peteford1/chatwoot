# Chatwoot Local Container Development & Deployment

This guide explains how to build, test, and deploy Chatwoot using container images instead of direct code deployment.

## 🎯 Why Container-Based Deployment?

**Benefits over direct code deployment:**
- ✅ **Consistency**: Same environment locally and in production
- ✅ **Reliability**: Pre-tested images reduce deployment failures
- ✅ **Speed**: Faster deployments with pre-built images
- ✅ **Rollback**: Easy to rollback to previous working images
- ✅ **Debugging**: Test everything locally before Azure deployment
- ✅ **CI/CD**: Automated builds and deployments via GitHub Actions

## 🛠️ Prerequisites

- Docker Desktop installed and running
- Docker Compose installed
- Azure CLI installed and logged in (`az login`)
- Access to `voicelinkregistry.azurecr.io` Azure Container Registry

## 🚀 Quick Start

### 1. Build and Test Locally

```bash
# Build, test, and validate the Chatwoot image locally
./scripts/build-and-test-local.sh
```

This script will:
- Build the Chatwoot container image
- Start PostgreSQL and Redis locally
- Run comprehensive health checks
- Test API endpoints
- Tag the image for Azure deployment

### 2. Deploy to Azure (After Local Validation)

```bash
# Deploy the validated image to Azure
./scripts/deploy-to-azure.sh
```

This script will:
- Push the validated image to Azure Container Registry
- Update/create the Azure Container App
- Verify the deployment
- Test the endpoints

## 📁 Project Structure

```
chatwoot/
├── docker/
│   └── Dockerfile.backend          # Production Chatwoot image
├── scripts/
│   ├── build-and-test-local.sh     # Local build & test script
│   ├── deploy-to-azure.sh          # Azure deployment script
│   └── init-db.sql                 # Database initialization
├── docker-compose.local.yml        # Local development stack
├── .github/workflows/
│   └── container-deploy.yml        # GitHub Actions CI/CD
└── README-LOCAL-DEVELOPMENT.md     # This file
```

## 🔧 Local Development Workflow

### Step 1: Build and Validate Locally

```bash
# Clean build and test
./scripts/build-and-test-local.sh

# Access your local Chatwoot
open http://localhost:3000/health
```

**What happens:**
- Builds custom Chatwoot image with proper startup scripts
- Starts PostgreSQL database with proper schema
- Starts Redis for caching and sessions
- Runs database migrations automatically
- Performs comprehensive health checks
- Tags image for Azure deployment

### Step 2: Test Thoroughly

```bash
# View logs
docker-compose -f docker-compose.local.yml logs -f chatwoot

# Test API endpoints
curl http://localhost:3000/health
curl http://localhost:3000/platform/api/v1/accounts

# Check database connection
docker-compose -f docker-compose.local.yml exec chatwoot \
  bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').first"

# Check Redis connection
docker-compose -f docker-compose.local.yml exec chatwoot \
  bundle exec rails runner "puts Redis.new(url: ENV['REDIS_URL']).ping"
```

### Step 3: Deploy to Azure

```bash
# Deploy validated image
./scripts/deploy-to-azure.sh

# Monitor deployment
az containerapp logs show --name chatwoot-test --resource-group SM-Test --follow
```

## 🏗️ Container Image Details

### Dockerfile Features

The `docker/Dockerfile.backend` includes:

- **Smart Startup Script**: Handles database preparation and health checks
- **Database Waiting**: Waits for database to be ready before starting
- **Automatic Migrations**: Runs `rails db:prepare` if needed
- **Health Checks**: Built-in health check endpoint
- **Production Ready**: Optimized for production deployment

### Environment Variables

**Local Development:**
```bash
RAILS_ENV=development
DATABASE_URL=postgresql://chatwootuser:ChatwootLocal2025!@postgres:5432/chatwoot_development
REDIS_URL=redis://redis:6379
SKIP_DATABASE_CREATION=false
```

**Azure Production:**
```bash
RAILS_ENV=production
DATABASE_URL=postgresql://chatwootuser:ChatwootSecure2025!@chatwoot-db-fresh.postgres.database.azure.com:5432/chatwoot_shared
REDIS_URL=redis://redis-shared.internal.calmmushroom-30b1c815.eastus.azurecontainerapps.io:6379
SKIP_DATABASE_CREATION=false
```

## 🔄 CI/CD with GitHub Actions

The `.github/workflows/container-deploy.yml` provides:

- **Automated Builds**: Builds images on code changes
- **Multi-Environment**: Separate dev/staging/prod deployments
- **Security Scanning**: Trivy vulnerability scanning
- **Automated Testing**: Health checks after deployment
- **Rollback Support**: Easy rollback to previous versions

### Triggering Deployments

```bash
# Deploy to development (develop branch)
git checkout develop
git push origin develop

# Deploy to production (main branch)
git checkout main
git merge develop
git push origin main
```

## 🐛 Troubleshooting

### Local Issues

**Container won't start:**
```bash
# Check logs
docker-compose -f docker-compose.local.yml logs chatwoot

# Rebuild without cache
docker-compose -f docker-compose.local.yml build --no-cache chatwoot
```

**Database connection issues:**
```bash
# Check database status
docker-compose -f docker-compose.local.yml exec postgres pg_isready -U chatwootuser

# Reset database
docker-compose -f docker-compose.local.yml down --volumes
./scripts/build-and-test-local.sh
```

**Port conflicts:**
```bash
# Check what's using port 3000
lsof -i :3000

# Use different ports in docker-compose.local.yml
```

### Azure Deployment Issues

**Image push fails:**
```bash
# Login to registry
az acr login --name voicelinkregistry

# Check registry access
az acr repository list --name voicelinkregistry
```

**Container app won't start:**
```bash
# Check logs
az containerapp logs show --name chatwoot-test --resource-group SM-Test --tail 50

# Check environment variables
az containerapp show --name chatwoot-test --resource-group SM-Test --query 'properties.template.containers[0].env'
```

## 📊 Monitoring and Maintenance

### Health Monitoring

```bash
# Local health check
curl http://localhost:3000/health

# Azure health check
curl https://chatwoot-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/health

# Via KrakenD gateway
curl http://voicelinkai.com/dev/health
```

### Log Monitoring

```bash
# Local logs
docker-compose -f docker-compose.local.yml logs -f chatwoot

# Azure logs
az containerapp logs show --name chatwoot-test --resource-group SM-Test --follow
```

### Performance Monitoring

```bash
# Container resource usage
docker stats chatwoot-backend-local

# Azure container metrics
az monitor metrics list --resource /subscriptions/535e2aa8-27e9-4d89-9208-be446ef89b87/resourceGroups/SM-Test/providers/Microsoft.App/containerApps/chatwoot-test
```

## 🔐 Security Best Practices

1. **Secrets Management**: Use Azure Key Vault for production secrets
2. **Image Scanning**: Trivy scans are included in CI/CD
3. **Registry Security**: Private Azure Container Registry
4. **Network Security**: Internal Redis access only
5. **Database Security**: SSL connections required

## 📈 Scaling and Optimization

### Local Development Scaling
```bash
# Scale services in docker-compose
docker-compose -f docker-compose.local.yml up --scale chatwoot=2
```

### Azure Scaling
```bash
# Update scaling rules
az containerapp update --name chatwoot-test --resource-group SM-Test --min-replicas 1 --max-replicas 5
```

## 🎯 Next Steps

1. **Test Locally**: Run `./scripts/build-and-test-local.sh`
2. **Validate Features**: Test all required functionality
3. **Deploy to Azure**: Run `./scripts/deploy-to-azure.sh`
4. **Monitor**: Watch logs and health endpoints
5. **Iterate**: Make changes and repeat the process

## 🆘 Support

- **Local Issues**: Check Docker Desktop and container logs
- **Azure Issues**: Check Azure Container Apps logs and metrics
- **CI/CD Issues**: Check GitHub Actions workflow logs
- **Database Issues**: Verify connection strings and credentials 