#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment configurations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/azure-environments.yml"

# Get the environment (default to test)
DEPLOY_ENV=${1:-test}
echo -e "${BLUE}🚀 Deploying to environment: $DEPLOY_ENV${NC}"

# Validate environment
if [[ ! "$DEPLOY_ENV" =~ ^(development|test|staging|production)$ ]]; then
    echo -e "${RED}[ERROR]${NC} Invalid environment: $DEPLOY_ENV"
    echo "Valid environments: development, test, staging, production"
    exit 1
fi

# Function to print status
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check for required tools
print_status "Checking required tools..."

# Check yq for YAML parsing
if ! command -v yq &> /dev/null; then
    print_status "Installing yq for YAML parsing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install yq
        else
            print_error "Please install Homebrew or install yq manually"
            exit 1
        fi
    else
        sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        sudo chmod +x /usr/local/bin/yq
    fi
fi

# Check Azure CLI
if ! command -v az >/dev/null 2>&1; then
    print_error "Azure CLI is not installed. Please install it first."
    exit 1
fi

# Check Docker
if ! command -v docker >/dev/null 2>&1; then
    print_error "Docker is not installed. Please install it first."
    exit 1
fi

print_success "All required tools are available"

# Extract environment-specific configuration
print_status "Loading configuration for environment: $DEPLOY_ENV"

if [ ! -f "$CONFIG_FILE" ]; then
    print_error "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

RESOURCE_GROUP=$(yq eval ".environments.$DEPLOY_ENV.resource_group" "$CONFIG_FILE")
APP_NAME=$(yq eval ".environments.$DEPLOY_ENV.name" "$CONFIG_FILE")
ENVIRONMENT_NAME=$(yq eval ".environments.$DEPLOY_ENV.environment" "$CONFIG_FILE")
CPU=$(yq eval ".environments.$DEPLOY_ENV.cpu" "$CONFIG_FILE")
MEMORY=$(yq eval ".environments.$DEPLOY_ENV.memory" "$CONFIG_FILE")
MIN_REPLICAS=$(yq eval ".environments.$DEPLOY_ENV.min_replicas" "$CONFIG_FILE")
MAX_REPLICAS=$(yq eval ".environments.$DEPLOY_ENV.max_replicas" "$CONFIG_FILE")
WORKLOAD_PROFILE=$(yq eval ".environments.$DEPLOY_ENV.workload_profile" "$CONFIG_FILE")

# KrakenD configuration
KRAKEND_APP_NAME=$(yq eval ".krakend.$DEPLOY_ENV.name" "$CONFIG_FILE")
KRAKEND_CPU=$(yq eval ".krakend.$DEPLOY_ENV.cpu" "$CONFIG_FILE")
KRAKEND_MEMORY=$(yq eval ".krakend.$DEPLOY_ENV.memory" "$CONFIG_FILE")
KRAKEND_MIN_REPLICAS=$(yq eval ".krakend.$DEPLOY_ENV.min_replicas" "$CONFIG_FILE")
KRAKEND_MAX_REPLICAS=$(yq eval ".krakend.$DEPLOY_ENV.max_replicas" "$CONFIG_FILE")
KRAKEND_WORKLOAD_PROFILE=$(yq eval ".krakend.$DEPLOY_ENV.workload_profile" "$CONFIG_FILE")

# Static configuration
LOCATION="eastus"
REGISTRY_NAME="voicelinkregistry"
REGISTRY="$REGISTRY_NAME.azurecr.io"
IMAGE_NAME="chatwoot-backend"
KRAKEND_IMAGE_NAME="krakend-gateway"
LOCAL_TAG="local-test"
AZURE_TAG="validated-$(date +%Y%m%d-%H%M%S)"

echo -e "${GREEN}📋 Configuration for $DEPLOY_ENV:${NC}"
echo "   Resource Group: $RESOURCE_GROUP"
echo "   App Name: $APP_NAME"
echo "   Environment: $ENVIRONMENT_NAME"
echo "   CPU: $CPU, Memory: $MEMORY"
echo "   Replicas: $MIN_REPLICAS-$MAX_REPLICAS"
echo "   Workload Profile: $WORKLOAD_PROFILE ($([ "$WORKLOAD_PROFILE" = "Consumption" ] && echo "Burstable" || echo "Dedicated"))"
echo "   KrakenD: $KRAKEND_APP_NAME ($KRAKEND_CPU CPU, $KRAKEND_MEMORY memory, $KRAKEND_WORKLOAD_PROFILE)"
echo "   Registry: $REGISTRY"

# Check if local image exists
print_status "Checking for locally validated image..."
if ! docker image inspect $REGISTRY/$IMAGE_NAME:$LOCAL_TAG >/dev/null 2>&1; then
    print_error "Local validated image not found: $REGISTRY/$IMAGE_NAME:$LOCAL_TAG"
    print_error "Please run './scripts/build-and-test-local.sh' first to build and validate the image locally"
    exit 1
fi
print_success "Local validated image found"

# Check Azure CLI authentication
print_status "Checking Azure CLI authentication..."
if ! az account show >/dev/null 2>&1; then
    print_error "Not logged into Azure CLI. Please run 'az login' first."
    exit 1
fi
print_success "Azure CLI authentication verified"

# Login to Azure Container Registry
print_status "Logging into Azure Container Registry..."
if ! az acr login --name $REGISTRY_NAME >/dev/null 2>&1; then
    print_error "Failed to login to Azure Container Registry"
    exit 1
fi
print_success "Logged into Azure Container Registry"

# Tag image for Azure deployment (ensure AMD64)
print_status "Tagging AMD64 image for Azure deployment..."
docker tag $REGISTRY/$IMAGE_NAME:$LOCAL_TAG $REGISTRY/$IMAGE_NAME:$AZURE_TAG
docker tag $REGISTRY/$IMAGE_NAME:$LOCAL_TAG $REGISTRY/$IMAGE_NAME:latest-$DEPLOY_ENV
print_success "Image tagged with Azure tags: $AZURE_TAG and latest-$DEPLOY_ENV"

# Push image to Azure Container Registry
print_status "Pushing AMD64 image to Azure Container Registry..."
docker push $REGISTRY/$IMAGE_NAME:$AZURE_TAG
docker push $REGISTRY/$IMAGE_NAME:latest-$DEPLOY_ENV
print_success "AMD64 image pushed to Azure Container Registry"

# Check if container environment exists
print_status "Checking if container environment exists..."
if ! az containerapp env show --name $ENVIRONMENT_NAME --resource-group $RESOURCE_GROUP >/dev/null 2>&1; then
    print_status "Creating container environment: $ENVIRONMENT_NAME"
    az containerapp env create \
        --name $ENVIRONMENT_NAME \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION
    print_success "Container environment created"
fi

# Build environment variables based on environment
declare -a ENV_VARS
case $DEPLOY_ENV in
    "development"|"test")
        ENV_VARS=(
            "RAILS_ENV=development"
            "NODE_ENV=development"
            "CW_API_ONLY_SERVER=true"
            "DATABASE_URL=postgresql://chatwootuser:ChatwootSecure2025!@chatwoot-db-fresh.postgres.database.azure.com:5432/chatwoot_shared?sslmode=require"
            "REDIS_URL=redis://redis-shared.calmmushroom-30b1c815.eastus.azurecontainerapps.io:6379"
            "SECRET_KEY_BASE=bb02bd4083fc907af6a7857e937af9067e1c68fde8995e90186545bb34e945f1"
            "FRONTEND_URL=https://$APP_NAME.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
            "FORCE_SSL=false"
            "RAILS_LOG_TO_STDOUT=true"
            "MAILER_SENDER_EMAIL=admin@voicelinkai.com"
            "SMTP_DOMAIN=voicelinkai.com"
            "ENABLE_ACCOUNT_SIGNUP=false"
            "SKIP_DATABASE_CREATION=false"
            "SIDEKIQ_CONCURRENCY=2"
        )
        ;;
    "staging")
        ENV_VARS=(
            "RAILS_ENV=staging"
            "NODE_ENV=staging"
            "CW_API_ONLY_SERVER=true"
            "DATABASE_URL=postgresql://chatwoot_staging:ChatwootSecure2025!@chatwoot-db-fresh.postgres.database.azure.com:5432/chatwoot_staging?sslmode=require"
            "REDIS_URL=redis://redis-shared.calmmushroom-30b1c815.eastus.azurecontainerapps.io:6379"
            "SECRET_KEY_BASE=bb02bd4083fc907af6a7857e937af9067e1c68fde8995e90186545bb34e945f1"
            "FRONTEND_URL=https://$APP_NAME.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
            "FORCE_SSL=true"
            "RAILS_LOG_TO_STDOUT=true"
            "MAILER_SENDER_EMAIL=admin@voicelinkai.com"
            "SMTP_DOMAIN=voicelinkai.com"
            "ENABLE_ACCOUNT_SIGNUP=false"
            "SKIP_DATABASE_CREATION=false"
            "SIDEKIQ_CONCURRENCY=3"
        )
        ;;
    "production")
        ENV_VARS=(
            "RAILS_ENV=production"
            "NODE_ENV=production"
            "CW_API_ONLY_SERVER=true"
            "DATABASE_URL=postgresql://chatwoot_prod:ChatwootSecure2025!@chatwoot-db-prod.postgres.database.azure.com:5432/chatwoot_production?sslmode=require"
            "REDIS_URL=redis://redis-prod.calmmushroom-30b1c815.eastus.azurecontainerapps.io:6379"
            "SECRET_KEY_BASE=bb02bd4083fc907af6a7857e937af9067e1c68fde8995e90186545bb34e945f1"
            "FRONTEND_URL=https://$APP_NAME.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
            "FORCE_SSL=true"
            "RAILS_LOG_TO_STDOUT=true"
            "MAILER_SENDER_EMAIL=admin@voicelinkai.com"
            "SMTP_DOMAIN=voicelinkai.com"
            "ENABLE_ACCOUNT_SIGNUP=false"
            "SKIP_DATABASE_CREATION=false"
            "SIDEKIQ_CONCURRENCY=8"
        )
        ;;
esac

# Check if container app exists
print_status "Checking if container app exists..."
if az containerapp show --name $APP_NAME --resource-group $RESOURCE_GROUP >/dev/null 2>&1; then
    print_status "Container app exists, updating..."
    UPDATE_MODE=true
else
    print_status "Container app doesn't exist, creating..."
    UPDATE_MODE=false
fi

# Build environment variables string for Azure CLI
ENV_VARS_STRING=""
for var in "${ENV_VARS[@]}"; do
    ENV_VARS_STRING="$ENV_VARS_STRING $var"
done

if [ "$UPDATE_MODE" = true ]; then
    # Update existing container app with environment-specific resources and workload profile
    print_status "Updating container app with AMD64 image, burstable instances, and environment-specific resources..."
    
    if [ "$WORKLOAD_PROFILE" = "Consumption" ]; then
        # Update with consumption-based (burstable) workload profile
        az containerapp update \
            --name $APP_NAME \
            --resource-group $RESOURCE_GROUP \
            --image $REGISTRY/$IMAGE_NAME:$AZURE_TAG \
            --cpu $CPU \
            --memory $MEMORY \
            --min-replicas $MIN_REPLICAS \
            --max-replicas $MAX_REPLICAS \
            --workload-profile-name "Consumption" \
            --set-env-vars $ENV_VARS_STRING
    else
        # Update with dedicated workload profile
        az containerapp update \
            --name $APP_NAME \
            --resource-group $RESOURCE_GROUP \
            --image $REGISTRY/$IMAGE_NAME:$AZURE_TAG \
            --cpu $CPU \
            --memory $MEMORY \
            --min-replicas $MIN_REPLICAS \
            --max-replicas $MAX_REPLICAS \
            --set-env-vars $ENV_VARS_STRING
    fi
else
    # Create new container app with environment-specific resources and workload profile
    print_status "Creating new container app with AMD64 image, burstable instances, and environment-specific resources..."
    
    if [ "$WORKLOAD_PROFILE" = "Consumption" ]; then
        # Create with consumption-based (burstable) workload profile
        az containerapp create \
            --name $APP_NAME \
            --resource-group $RESOURCE_GROUP \
            --environment $ENVIRONMENT_NAME \
            --image $REGISTRY/$IMAGE_NAME:$AZURE_TAG \
            --target-port 3000 \
            --ingress external \
            --cpu $CPU \
            --memory $MEMORY \
            --min-replicas $MIN_REPLICAS \
            --max-replicas $MAX_REPLICAS \
            --workload-profile-name "Consumption" \
            --env-vars $ENV_VARS_STRING
    else
        # Create with dedicated workload profile
        az containerapp create \
            --name $APP_NAME \
            --resource-group $RESOURCE_GROUP \
            --environment $ENVIRONMENT_NAME \
            --image $REGISTRY/$IMAGE_NAME:$AZURE_TAG \
            --target-port 3000 \
            --ingress external \
            --cpu $CPU \
            --memory $MEMORY \
            --min-replicas $MIN_REPLICAS \
            --max-replicas $MAX_REPLICAS \
            --env-vars $ENV_VARS_STRING
    fi
fi

if [ $? -eq 0 ]; then
    print_success "Container app deployment completed with environment-specific resources"
    echo "   CPU: $CPU, Memory: $MEMORY"
    echo "   Replicas: $MIN_REPLICAS-$MAX_REPLICAS"
    echo "   Architecture: AMD64"
    echo "   Workload Profile: $WORKLOAD_PROFILE ($([ "$WORKLOAD_PROFILE" = "Consumption" ] && echo "Burstable - Pay per use" || echo "Dedicated - Always allocated"))"
else
    print_error "Container app deployment failed"
    exit 1
fi

# Wait for deployment to complete
print_status "Waiting for deployment to complete..."
sleep 60

# Get the app URL
APP_URL="https://$APP_NAME.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
HEALTH_URL="$APP_URL/health"

# Verify deployment
print_status "Verifying deployment..."
timeout=300
counter=0
while [ $counter -lt $timeout ]; do
    if curl -f $HEALTH_URL >/dev/null 2>&1; then
        print_success "✅ Deployment verified - Health endpoint is responding"
        break
    fi
    sleep 10
    counter=$((counter + 10))
    echo -n "."
done

if [ $counter -ge $timeout ]; then
    print_warning "⚠️  Health endpoint not responding within $timeout seconds"
    print_status "Checking container logs..."
    az containerapp logs show --name $APP_NAME --resource-group $RESOURCE_GROUP --tail 20
else
    # Test API endpoints
    print_status "Testing API endpoints..."
    if curl -f -H "Accept: application/json" "$APP_URL/platform/api/v1/accounts" >/dev/null 2>&1; then
        print_success "✅ Platform API is accessible"
    else
        print_warning "⚠️  Platform API might need authentication (expected)"
    fi
fi

# Update KrakenD configuration for the deployed environment
print_status "Updating KrakenD configuration for environment..."
if [ -f "./scripts/update-krakend-config.sh" ]; then
    chmod +x ./scripts/update-krakend-config.sh
    
    print_status "Updating KrakenD for environment: $DEPLOY_ENV"
    ./scripts/update-krakend-config.sh $DEPLOY_ENV update
    
    if [ $? -eq 0 ]; then
        print_success "✅ KrakenD configuration updated and deployed"
    else
        print_warning "⚠️  KrakenD configuration update failed, but Chatwoot deployment succeeded"
    fi
else
    print_warning "⚠️  KrakenD configuration script not found"
fi

# Test gateway routing
print_status "Testing KrakenD gateway routing..."
GATEWAY_PATH="dev"
if [[ "$DEPLOY_ENV" == "staging" ]]; then
    GATEWAY_PATH="staging"
elif [[ "$DEPLOY_ENV" == "production" ]]; then
    GATEWAY_PATH="prod"
fi

if curl -f "http://voicelinkai.com/$GATEWAY_PATH/health" >/dev/null 2>&1; then
    print_success "✅ Gateway routing is working"
    echo "  Gateway URL: http://voicelinkai.com/$GATEWAY_PATH/"
else
    print_warning "⚠️  Gateway routing might need manual configuration update"
    echo "  Try: ./scripts/update-krakend-config.sh $DEPLOY_ENV update"
fi

# Show deployment information
echo ""
echo -e "${GREEN}🎉 Deployment Complete for $DEPLOY_ENV!${NC}"
echo "========================================"
echo -e "✅ Environment: ${BLUE}$DEPLOY_ENV${NC}"
echo -e "✅ Architecture: ${BLUE}AMD64${NC}"
echo -e "✅ Resources: ${BLUE}$CPU CPU, $MEMORY memory${NC}"
echo -e "✅ Scaling: ${BLUE}$MIN_REPLICAS-$MAX_REPLICAS replicas${NC}"
echo -e "✅ Direct Access: ${BLUE}$APP_URL${NC}"
echo -e "✅ Via Gateway: ${BLUE}http://voicelinkai.com/$GATEWAY_PATH/${NC}"
echo -e "✅ Health Check: ${BLUE}$HEALTH_URL${NC}"
echo ""
echo "Monitor deployment:"
echo "  az containerapp logs show --name $APP_NAME --resource-group $RESOURCE_GROUP --follow"
echo ""
echo "Scale if needed:"
echo "  az containerapp update --name $APP_NAME --resource-group $RESOURCE_GROUP --min-replicas X --max-replicas Y"
echo ""
echo "Rollback if needed:"
echo "  az containerapp update --name $APP_NAME --resource-group $RESOURCE_GROUP --image $REGISTRY/$IMAGE_NAME:previous-tag" 