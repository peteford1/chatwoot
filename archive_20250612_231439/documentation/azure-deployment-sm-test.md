# Azure Chatwoot Backend Deployment - SM_test Environment

## **Deployment Configuration for Testing Instance**

### **Step 1: Set Variables and Login**

```bash
# Set your variables for SM_test resource group
RESOURCE_GROUP="SM_test"
LOCATION="eastus"
CONTAINER_APP_NAME="chatwoot-backend-test"
POSTGRES_SERVER_NAME="chatwoot-postgres-$(date +%s)"
ADMIN_USER="chatwootadmin"
ADMIN_PASSWORD="ChatwootAdmin123!"
DB_NAME="chatwoot_production"
CONTAINER_APP_ENV="chatwoot-env-test"

# Login to Azure
az login
az account set --subscription "your-subscription-id"
```

### **Step 2: Create Container App Environment**

```bash
# Create Container Apps environment in SM_test resource group
az containerapp env create \
  --name $CONTAINER_APP_ENV \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION
```

### **Step 3: Create Azure Database for PostgreSQL**

```bash
# Create PostgreSQL Flexible Server with pgvector extension
az postgres flexible-server create \
  --resource-group $RESOURCE_GROUP \
  --name $POSTGRES_SERVER_NAME \
  --location $LOCATION \
  --admin-user $ADMIN_USER \
  --admin-password $ADMIN_PASSWORD \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --version 14 \
  --storage-size 32 \
  --public-access 0.0.0.0

# Create the database
az postgres flexible-server db create \
  --resource-group $RESOURCE_GROUP \
  --server-name $POSTGRES_SERVER_NAME \
  --database-name $DB_NAME

# Enable pgvector extension
az postgres flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $POSTGRES_SERVER_NAME \
  --name shared_preload_libraries \
  --value "vector"

# Configure firewall rule for Azure services
az postgres flexible-server firewall-rule create \
  --resource-group $RESOURCE_GROUP \
  --name $POSTGRES_SERVER_NAME \
  --rule-name "AllowAzureServices" \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

### **Step 4: Create Container App with Redis Sidecar (1 CPU)**

```bash
# Get PostgreSQL connection string
POSTGRES_HOST="${POSTGRES_SERVER_NAME}.postgres.database.azure.com"
DATABASE_URL="postgresql://${ADMIN_USER}:${ADMIN_PASSWORD}@${POSTGRES_HOST}:5432/${DB_NAME}?sslmode=require"

# Create the Container App with both Chatwoot backend and Redis
az containerapp create \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINER_APP_ENV \
  --cpu 1.0 \
  --memory 2.0Gi \
  --min-replicas 1 \
  --max-replicas 1 \
  --target-port 3000 \
  --ingress external \
  --env-vars \
    RAILS_ENV=production \
    CW_API_ONLY_SERVER=true \
    DATABASE_URL="$DATABASE_URL" \
    REDIS_URL=redis://localhost:6379 \
    SECRET_KEY_BASE=$(openssl rand -hex 64) \
    FRONTEND_URL=https://your-frontend-domain.com \
    FORCE_SSL=false \
    RAILS_LOG_TO_STDOUT=true \
    MAILER_SENDER_EMAIL=noreply@yourdomain.com \
    SMTP_DOMAIN=yourdomain.com \
    ENABLE_ACCOUNT_SIGNUP=false \
  --image chatwoot/chatwoot:latest \
  --command "/bin/sh" \
  --args "-c,bundle exec rails db:prepare && bundle exec rails server -b 0.0.0.0 -p 3000"
```

### **Step 5: Add Redis Sidecar Container**

```bash
# Add Redis as a sidecar container
az containerapp revision copy \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --yaml redis-sidecar.yaml
```

Create the `redis-sidecar.yaml` file:

```yaml
# redis-sidecar.yaml
properties:
  template:
    containers:
    - name: chatwoot-backend
      image: chatwoot/chatwoot:latest
      command:
      - /bin/sh
      args:
      - -c
      - bundle exec rails db:prepare && bundle exec rails server -b 0.0.0.0 -p 3000
      env:
      - name: RAILS_ENV
        value: production
      - name: CW_API_ONLY_SERVER
        value: "true"
      - name: DATABASE_URL
        value: "postgresql://chatwootadmin:ChatwootAdmin123!@chatwoot-postgres-xxxxx.postgres.database.azure.com:5432/chatwoot_production?sslmode=require"
      - name: REDIS_URL
        value: redis://localhost:6379
      - name: SECRET_KEY_BASE
        value: "your-generated-secret-key"
      - name: FRONTEND_URL
        value: https://your-frontend-domain.com
      - name: FORCE_SSL
        value: "false"
      - name: RAILS_LOG_TO_STDOUT
        value: "true"
      - name: MAILER_SENDER_EMAIL
        value: noreply@yourdomain.com
      - name: SMTP_DOMAIN
        value: yourdomain.com
      - name: ENABLE_ACCOUNT_SIGNUP
        value: "false"
      resources:
        cpu: 0.75
        memory: 1.5Gi
    - name: redis
      image: redis:7-alpine
      command:
      - redis-server
      - --appendonly
      - "yes"
      - --maxmemory
      - 256mb
      - --maxmemory-policy
      - allkeys-lru
      resources:
        cpu: 0.25
        memory: 0.5Gi
    scale:
      minReplicas: 1
      maxReplicas: 1
```

### **Step 6: Configure Database and Initialize**

```bash
# Get the container app URL
CONTAINER_APP_URL=$(az containerapp show \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "properties.configuration.ingress.fqdn" \
  --output tsv)

echo "Container App URL: https://$CONTAINER_APP_URL"

# Create a super admin user (run this after the app is deployed)
az containerapp exec \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --container chatwoot-backend \
  --command "bundle exec rails runner \"user = User.create!(name: 'Admin', email: 'admin@test.com', password: 'password123', password_confirmation: 'password123', confirmed_at: Time.current); Account.create!(name: 'Test Account'); AccountUser.create!(user: user, account: Account.first, role: 'administrator')\""
```

### **Step 7: Health Check and Verification**

```bash
# Check container app status
az containerapp show \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "properties.runningStatus"

# View logs
az containerapp logs show \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --follow

# Test the API endpoint
curl -X GET "https://$CONTAINER_APP_URL/api/v1/accounts/1" \
  -H "Content-Type: application/json"
```

## **Resource Allocation Summary**

- **Total CPU**: 1.0 core
  - Chatwoot Backend: 0.75 cores
  - Redis Sidecar: 0.25 cores
- **Total Memory**: 2.0Gi
  - Chatwoot Backend: 1.5Gi
  - Redis Sidecar: 0.5Gi
- **Resource Group**: SM_test
- **Scaling**: Fixed to 1 replica (no auto-scaling for testing)

## **Cost Optimization Features**

1. **Minimal CPU allocation** (1 core total)
2. **Local Redis** instead of Azure Cache
3. **Burstable PostgreSQL tier** (Standard_B1ms)
4. **Single replica** deployment
5. **32GB storage** for database (minimum)

## **API Endpoints Available**

Once deployed, your backend will be available at:
- **Base URL**: `https://[container-app-url]`
- **API Base**: `https://[container-app-url]/api/v1/`
- **Health Check**: `https://[container-app-url]/health`

## **Next Steps**

1. Update the `DATABASE_URL` in the YAML file with your actual PostgreSQL server name
2. Generate a proper `SECRET_KEY_BASE` using `openssl rand -hex 64`
3. Configure your frontend to point to this backend URL
4. Set up proper domain and SSL certificates if needed
5. Configure SMTP settings for email notifications

This configuration provides a cost-effective testing environment with all services co-located in the SM_test resource group. 