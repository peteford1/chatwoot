# Chatwoot Azure Deployment Guide

## Complete Step-by-Step Guide for Deploying Chatwoot on Azure Container Apps

This guide documents the complete process for deploying a Chatwoot instance on Azure with custom code, including all configurations, permissions, and troubleshooting steps.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Azure Container Registry Setup](#azure-container-registry-setup)
3. [PostgreSQL Database Setup](#postgresql-database-setup)
4. [Custom Docker Image Creation](#custom-docker-image-creation)
5. [Azure Container Apps Deployment](#azure-container-apps-deployment)
6. [KrakenD API Gateway Configuration](#krakend-api-gateway-configuration)
7. [DNS and Domain Configuration](#dns-and-domain-configuration)
8. [Security and Access Control](#security-and-access-control)
9. [Troubleshooting Common Issues](#troubleshooting-common-issues)
10. [Maintenance and Updates](#maintenance-and-updates)

---

## Prerequisites

### Required Tools
```bash
# Install Azure CLI
brew install azure-cli

# Install Docker
brew install docker

# Install PostgreSQL client
brew install postgresql
```

### Azure Login
```bash
az login
az account set --subscription "your-subscription-id"
```

### Environment Variables
```bash
export RESOURCE_GROUP="SM-Test"
export LOCATION="East US"
export REGISTRY_NAME="chatwootregistry95290"
export DB_NAME="chatwoot-db-fresh"
export CONTAINER_APP_NAME="chatwoot-backend-test"
export ENVIRONMENT_NAME="chatwoot-env-test"
```

---

## Azure Container Registry Setup

### 1. Create Container Registry
```bash
# Create Azure Container Registry
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $REGISTRY_NAME \
  --sku Basic \
  --location "$LOCATION"

# Enable admin access
az acr update \
  --name $REGISTRY_NAME \
  --admin-enabled true

# Get registry credentials
az acr credential show --name $REGISTRY_NAME
```

### 2. Docker Login to Registry
```bash
# Login to Azure Container Registry
az acr login --name $REGISTRY_NAME

# Or use Docker login with credentials
docker login ${REGISTRY_NAME}.azurecr.io \
  --username $REGISTRY_NAME \
  --password "your-registry-password"
```

---

## PostgreSQL Database Setup

### 1. Create PostgreSQL Flexible Server
```bash
# Create PostgreSQL server
az postgres flexible-server create \
  --resource-group $RESOURCE_GROUP \
  --name $DB_NAME \
  --location "$LOCATION" \
  --admin-user chatwootuser \
  --admin-password chatwoot123 \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --storage-size 32 \
  --version 16 \
  --public-access 0.0.0.0
```

### 2. Create Database
```bash
# Create the chatwoot_production database
az postgres flexible-server db create \
  --resource-group $RESOURCE_GROUP \
  --server-name $DB_NAME \
  --database-name chatwoot_production
```

### 3. Configure Firewall Rules
```bash
# Allow Azure services
az postgres flexible-server firewall-rule create \
  --resource-group $RESOURCE_GROUP \
  --name $DB_NAME \
  --rule-name AllowAllAzureIps \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

# Allow all IPs (for initial setup - restrict later)
az postgres flexible-server firewall-rule create \
  --resource-group $RESOURCE_GROUP \
  --name $DB_NAME \
  --rule-name AllowAll \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 255.255.255.255
```

### 4. Enable Required PostgreSQL Extensions
```bash
# Enable required extensions at server level
az postgres flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $DB_NAME \
  --name azure.extensions \
  --value "pgcrypto,pg_trgm,pg_stat_statements,plpgsql,vector"

# Enable shared_preload_libraries (requires restart)
az postgres flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $DB_NAME \
  --name shared_preload_libraries \
  --value "pg_stat_statements"

# Restart server to apply changes
az postgres flexible-server restart \
  --resource-group $RESOURCE_GROUP \
  --name $DB_NAME
```

### 5. Create Extensions in Database
```bash
# Connect and create extensions
psql "postgresql://chatwootuser:chatwoot123@${DB_NAME}.postgres.database.azure.com:5432/chatwoot_production" \
  -c "CREATE EXTENSION IF NOT EXISTS pgcrypto; 
      CREATE EXTENSION IF NOT EXISTS pg_trgm; 
      CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
```

---

## Custom Docker Image Creation

### 1. Dockerfile for Azure Compatibility
Create `Dockerfile.azure-complete`:
```dockerfile
FROM chatwoot/chatwoot:latest

# Fix Azure PostgreSQL compatibility for all problematic extensions
USER root

# Comment out all problematic extensions that are not allowed in Azure PostgreSQL
RUN sed -i 's/enable_extension "pg_stat_statements"/# enable_extension "pg_stat_statements" # Disabled for Azure PostgreSQL/' /app/db/migrate/20230426130150_init_schema.rb && \
    sed -i 's/enable_extension "pg_trgm"/# enable_extension "pg_trgm" # Disabled for Azure PostgreSQL/' /app/db/migrate/20230426130150_init_schema.rb

# Verify the changes
RUN grep -n "enable_extension" /app/db/migrate/20230426130150_init_schema.rb

# Switch back to the app user
USER 1001

# Set the default command
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
```

### 2. Custom Code Integration
For deployments with custom code, create `Dockerfile.custom`:
```dockerfile
FROM chatwoot/chatwoot:latest

# Copy custom code
USER root

# Copy custom controllers
COPY custom/controllers/ /app/custom/controllers/
COPY custom/services/ /app/custom/services/
COPY custom/lib/ /app/custom/lib/

# Copy modified routes file
COPY config/routes.rb /app/config/routes.rb

# Copy custom configuration files
COPY custom/config/ /app/custom/config/

# Fix autoload configuration for custom paths
RUN echo "Rails.application.config.autoload_paths += Dir[Rails.root.join('custom', '**')]" >> /app/config/application.rb

# Set proper permissions
RUN chown -R 1001:1001 /app/custom/

# Switch back to app user
USER 1001

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
```

### 3. Build and Push Images
```bash
# Build for Azure (linux/amd64 platform)
docker buildx build --platform linux/amd64 \
  -f Dockerfile.azure-complete \
  -t ${REGISTRY_NAME}.azurecr.io/chatwoot-azure-fixed:latest \
  --push .

# For custom code deployment
docker buildx build --platform linux/amd64 \
  -f Dockerfile.custom \
  -t ${REGISTRY_NAME}.azurecr.io/chatwoot-with-custom:latest \
  --push .
```

---

## Azure Container Apps Deployment

### 1. Create Container Apps Environment
```bash
# Create the environment
az containerapp env create \
  --name $ENVIRONMENT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location "$LOCATION"
```

### 2. Generate SECRET_KEY_BASE
```bash
# Generate a secure secret key
SECRET_KEY_BASE=$(openssl rand -hex 64)
echo "SECRET_KEY_BASE: $SECRET_KEY_BASE"
```

### 3. Deploy Container App
```bash
# Create the container app
az containerapp create \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $ENVIRONMENT_NAME \
  --image ${REGISTRY_NAME}.azurecr.io/chatwoot-azure-fixed:latest \
  --registry-server ${REGISTRY_NAME}.azurecr.io \
  --registry-username $REGISTRY_NAME \
  --registry-password "your-registry-password" \
  --target-port 3000 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 2 \
  --cpu 0.75 \
  --memory 1.5Gi \
  --env-vars \
    DATABASE_URL="postgresql://chatwootuser:chatwoot123@${DB_NAME}.postgres.database.azure.com:5432/chatwoot_production" \
    SECRET_KEY_BASE="$SECRET_KEY_BASE" \
    RAILS_ENV="production"
```

### 4. Add Redis Sidecar
```bash
# Update container app to include Redis sidecar
az containerapp update \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --container-name redis \
  --image redis:7-alpine \
  --cpu 0.25 \
  --memory 0.5Gi \
  --command "redis-server" \
  --args "--appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru"
```

---

## KrakenD API Gateway Configuration

### 1. KrakenD Configuration File
Create `krakend.json`:
```json
{
  "version": 3,
  "name": "Chatwoot API Gateway",
  "timeout": "3000ms",
  "cache_ttl": "300s",
  "output_encoding": "json",
  "port": 8080,
  "endpoints": [
    {
      "endpoint": "/api/{path}",
      "method": "GET",
      "output_encoding": "no-op",
      "backend": [
        {
          "url_pattern": "/api/{path}",
          "encoding": "no-op",
          "method": "GET",
          "host": [
            "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
          ]
        }
      ]
    },
    {
      "endpoint": "/api/{path}",
      "method": "POST",
      "output_encoding": "no-op",
      "backend": [
        {
          "url_pattern": "/api/{path}",
          "encoding": "no-op",
          "method": "POST",
          "host": [
            "https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
          ]
        }
      ]
    }
  ],
  "extra_config": {
    "security/cors": {
      "allow_origins": ["*"],
      "allow_methods": ["GET", "POST", "PUT", "DELETE"],
      "allow_headers": ["*"]
    }
  }
}
```

### 2. Deploy KrakenD
```bash
# Create KrakenD container app
az containerapp create \
  --name chatwoot-gateway \
  --resource-group $RESOURCE_GROUP \
  --environment $ENVIRONMENT_NAME \
  --image devopsfaith/krakend:latest \
  --target-port 8080 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 2 \
  --cpu 0.5 \
  --memory 1Gi
```

---

## DNS and Domain Configuration

### 1. Custom Domain Setup
```bash
# Add custom domain to container app
az containerapp hostname add \
  --hostname voicelinkai.com \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP

# Get domain verification ID
az containerapp show \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "properties.customDomainVerificationId"
```

### 2. DNS Records
Add these DNS records to your domain:
```
# CNAME record
voicelinkai.com -> chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io

# TXT record for verification
asuid.voicelinkai.com -> your-domain-verification-id
```

### 3. SSL Certificate
```bash
# Bind SSL certificate (automatic with managed certificate)
az containerapp hostname bind \
  --hostname voicelinkai.com \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --validation-method CNAME
```

---

## SuperAdmin User Creation

After successful deployment, you need to create a SuperAdmin user to access the administrative interface.

### 1. Create SuperAdmin User Script
Create a script `create_superadmin.rb`:
```ruby
#!/usr/bin/env ruby

require 'pg'
require 'bcrypt'
require 'securerandom'

# Database connection
conn = PG.connect(
  host: 'chatwoot-db-fresh.postgres.database.azure.com',
  port: 5432,
  dbname: 'chatwoot_production',
  user: 'chatwootuser',
  password: 'chatwoot123'
)

begin
  # User details
  email = 'admin@voicelinkai.com'
  name = 'Super Admin'
  password = 'SuperAdmin123!'
  
  # Generate required fields
  password_hash = BCrypt::Password.create(password)
  uid = SecureRandom.uuid
  provider = 'email'
  
  puts "Creating SuperAdmin user..."
  puts "Email: #{email}"
  puts "Password: #{password}"
  
  # Insert the user
  result = conn.exec_params(
    "INSERT INTO users (email, name, encrypted_password, uid, provider, type, confirmed_at, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW(), NOW()) RETURNING id",
    [email, name, password_hash, uid, provider, 'SuperAdmin']
  )
  
  if result.ntuples > 0
    user_id = result[0]['id']
    puts "\n✅ SuperAdmin user created successfully!"
    puts "User ID: #{user_id}"
    puts "\n🎉 You can now login at:"
    puts "URL: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/super_admin/sign_in"
    puts "Email: #{email}"
    puts "Password: #{password}"
  else
    puts "\n❌ Failed to create user"
  end
  
rescue PG::Error => e
  puts "Database error: #{e.message}"
ensure
  conn.close if conn
end
```

### 2. Install Required Gems
```bash
gem install pg bcrypt
```

### 3. Run SuperAdmin Creation
```bash
ruby create_superadmin.rb
```

### 4. Verify SuperAdmin Access
- **URL**: `https://your-container-app-url/super_admin/sign_in`
- **Email**: `admin@voicelinkai.com`
- **Password**: `SuperAdmin123!`

### 5. Email Configuration (Optional)
To enable password reset functionality, add email environment variables:
```bash
az containerapp update \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --container-name chatwoot-backend \
  --set-env-vars \
    MAILER_SENDER_EMAIL="admin@voicelinkai.com" \
    SMTP_DOMAIN="voicelinkai.com" \
    SMTP_ADDRESS="localhost" \
    SMTP_PORT="25" \
    FRONTEND_URL="https://your-domain.com"
```

### 6. Create Admin API Token (For Custom Code)
If your custom code needs to make API calls to Chatwoot, create an admin API token:

Create `create_admin_api_token.rb`:
```ruby
#!/usr/bin/env ruby

require 'pg'
require 'securerandom'

conn = PG.connect(
  host: 'chatwoot-db-fresh.postgres.database.azure.com',
  port: 5432,
  dbname: 'chatwoot_production',
  user: 'chatwootuser',
  password: 'chatwoot123'
)

begin
  # Find SuperAdmin user
  user_result = conn.exec("SELECT id FROM users WHERE type = 'SuperAdmin' LIMIT 1")
  user_id = user_result[0]['id']
  
  # Generate API token
  token = SecureRandom.hex(12)
  
  # Insert access token
  token_result = conn.exec_params(
    "INSERT INTO access_tokens (owner_id, owner_type, token, created_at, updated_at) VALUES ($1, $2, $3, NOW(), NOW()) RETURNING token",
    [user_id, 'User', token]
  )
  
  puts "Admin API Token: #{token_result[0]['token']}"
rescue PG::Error => e
  puts "Error: #{e.message}"
ensure
  conn.close if conn
end
```

Run the script and add the token to environment variables:
```bash
ruby create_admin_api_token.rb
# Copy the generated token

az containerapp update \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --container-name chatwoot-backend \
  --set-env-vars CHATWOOT_ADMIN_API_TOKEN="your-generated-token"
```

### 7. Using Admin API Token in Custom Code
```ruby
# In your custom services/controllers
class CustomChatwootService
  def initialize
    @api_token = ENV['CHATWOOT_ADMIN_API_TOKEN']
    @base_url = ENV['FRONTEND_URL']
  end

  def get_admin_profile
    # Make API request with token
    headers = { 'api_access_token' => @api_token }
    # ... rest of implementation
  end
end
```

### 8. Troubleshooting SuperAdmin Login
If you get "invalid credentials":
1. Clear browser cache and cookies
2. Try an incognito/private browser window
3. Verify the user exists in database:
   ```bash
   psql "postgresql://chatwootuser:chatwoot123@${DB_NAME}.postgres.database.azure.com:5432/chatwoot_production" \
     -c "SELECT id, email, type, confirmed_at FROM users WHERE type = 'SuperAdmin';"
   ```
4. Check container logs for authentication errors

---

## Security and Access Control

### 1. IP Restrictions
```bash
# Add IP restrictions for security
az containerapp ingress access-restriction set \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --rule-name allow-krakend-only \
  --ip-address 4.155.89.197/32 \
  --action Allow

az containerapp ingress access-restriction set \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --rule-name allow-dev-access \
  --ip-address 66.235.2.63/32 \
  --action Allow

# Temporary rule for initial setup (remove after setup)
az containerapp ingress access-restriction set \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --rule-name allow-all-temp \
  --ip-address 0.0.0.0/0 \
  --action Allow
```

### 2. Database Security
```bash
# Restrict database access (remove AllowAll rule after setup)
az postgres flexible-server firewall-rule delete \
  --resource-group $RESOURCE_GROUP \
  --name $DB_NAME \
  --rule-name AllowAll \
  --yes
```

### 3. Container Registry Security
```bash
# Disable admin access after deployment
az acr update \
  --name $REGISTRY_NAME \
  --admin-enabled false
```

---

## Troubleshooting Common Issues

### 1. PostgreSQL Extension Issues
If you encounter extension errors:
```bash
# Check available extensions
psql "postgresql://chatwootuser:chatwoot123@${DB_NAME}.postgres.database.azure.com:5432/chatwoot_production" \
  -c "SELECT name FROM pg_available_extensions ORDER BY name;"

# Check enabled extensions
psql "postgresql://chatwootuser:chatwoot123@${DB_NAME}.postgres.database.azure.com:5432/chatwoot_production" \
  -c "SELECT extname FROM pg_extension;"

# Enable missing extensions
az postgres flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $DB_NAME \
  --name azure.extensions \
  --value "pgcrypto,pg_trgm,pg_stat_statements,plpgsql,vector"
```

### 2. Container Startup Issues
```bash
# Check container logs
az containerapp logs show \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --tail 50

# Restart container
az containerapp revision restart \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --revision "latest-revision-name"
```

### 3. Database Connection Issues
```bash
# Test database connectivity
psql "postgresql://chatwootuser:chatwoot123@${DB_NAME}.postgres.database.azure.com:5432/chatwoot_production" \
  -c "SELECT 1 as test;"

# Check firewall rules
az postgres flexible-server firewall-rule list \
  --resource-group $RESOURCE_GROUP \
  --name $DB_NAME
```

### 4. Custom Code Issues
If custom code fails to load:
```bash
# Check autoload paths in Rails console
# Add to config/application.rb:
Rails.application.config.autoload_paths += Dir[Rails.root.join('custom', '**')]

# Verify file permissions
RUN chown -R 1001:1001 /app/custom/
```

---

## Maintenance and Updates

### 1. Update Container Image
```bash
# Build new image
docker buildx build --platform linux/amd64 \
  -f Dockerfile.azure-complete \
  -t ${REGISTRY_NAME}.azurecr.io/chatwoot-azure-fixed:v2 \
  --push .

# Update container app
az containerapp update \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --container-name chatwoot-backend \
  --image ${REGISTRY_NAME}.azurecr.io/chatwoot-azure-fixed:v2
```

### 2. Database Backup
```bash
# Create database backup
az postgres flexible-server backup create \
  --resource-group $RESOURCE_GROUP \
  --name $DB_NAME \
  --backup-name "backup-$(date +%Y%m%d)"
```

### 3. Scale Container App
```bash
# Scale up/down
az containerapp update \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --min-replicas 2 \
  --max-replicas 5
```

### 4. Monitor Resources
```bash
# Check container app status
az containerapp show \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "properties.runningStatus"

# Check database metrics
az postgres flexible-server show \
  --resource-group $RESOURCE_GROUP \
  --name $DB_NAME \
  --query "state"
```

---

## Environment Variables Reference

### Required Environment Variables
```bash
# Database
DATABASE_URL="postgresql://chatwootuser:chatwoot123@${DB_NAME}.postgres.database.azure.com:5432/chatwoot_production"

# Security
SECRET_KEY_BASE="your-64-character-hex-string"

# Rails
RAILS_ENV="production"

# Optional - Redis (if using external Redis)
REDIS_URL="redis://localhost:6379"

# Optional - Frontend URL
FRONTEND_URL="https://voicelinkai.com"
```

### Custom Environment Variables
```bash
# For custom features
CUSTOM_FEATURE_ENABLED="true"
SYNC_ACCOUNTS_ENABLED="true"
```

---

## File Structure for Custom Deployment

```
chatwoot/
├── custom/
│   ├── controllers/
│   │   └── api/
│   │       └── v1/
│   │           └── sync_accounts_controller.rb
│   ├── services/
│   │   └── sync_accounts_service.rb
│   ├── lib/
│   │   └── custom_extensions/
│   └── config/
│       └── custom_routes.rb
├── config/
│   └── routes.rb (modified)
├── Dockerfile.custom
├── Dockerfile.azure-complete
├── krakend.json
└── CHATWOOT_AZURE_DEPLOYMENT_GUIDE.md
```

---

## Quick Deployment Checklist

- [ ] Azure CLI installed and logged in
- [ ] Resource group created
- [ ] Container registry created and configured
- [ ] PostgreSQL server created with extensions enabled
- [ ] Database created and extensions installed
- [ ] Docker image built and pushed
- [ ] Container Apps environment created
- [ ] Container app deployed with proper environment variables
- [ ] Redis sidecar added
- [ ] IP restrictions configured
- [ ] Domain and SSL configured
- [ ] KrakenD gateway deployed (if needed)
- [ ] Initial SuperAdmin user created
- [ ] Temporary access rules removed

---

## Support and Troubleshooting

### Common Commands for Debugging
```bash
# Get container app URL
az containerapp show \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "properties.configuration.ingress.fqdn"

# Test API connectivity
curl -s "https://your-container-app-url/api/v1/profile" \
  -H "api_access_token: your-token"

# Check database connectivity
psql "postgresql://chatwootuser:chatwoot123@${DB_NAME}.postgres.database.azure.com:5432/chatwoot_production" \
  -c "SELECT COUNT(*) FROM users;"
```

### Log Analysis
```bash
# Real-time logs
az containerapp logs show \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --follow

# Filter logs by container
az containerapp logs show \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --container-name chatwoot-backend \
  --tail 100
```

---

**Last Updated**: June 2025  
**Version**: 1.0  
**Tested With**: Chatwoot latest, Azure Container Apps, PostgreSQL 16 