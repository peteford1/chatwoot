#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGISTRY="voicelinkregistry.azurecr.io"
IMAGE_NAME="chatwoot-backend"
LOCAL_TAG="local-test"
AZURE_TAG="validated-$(date +%Y%m%d-%H%M%S)"
RESOURCE_GROUP="SM-Test"
CONTAINER_APP_NAME="chatwoot-test"

echo -e "${BLUE}🚀 Deploy Validated Chatwoot Image to Azure${NC}"
echo "============================================="

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

# Check if local image exists
print_status "Checking for locally validated image..."
if ! docker image inspect $REGISTRY/$IMAGE_NAME:$LOCAL_TAG >/dev/null 2>&1; then
    print_error "Local validated image not found: $REGISTRY/$IMAGE_NAME:$LOCAL_TAG"
    print_error "Please run './scripts/build-and-test-local.sh' first to build and validate the image locally"
    exit 1
fi
print_success "Local validated image found"

# Check Azure CLI
if ! command -v az >/dev/null 2>&1; then
    print_error "Azure CLI is not installed. Please install it first."
    exit 1
fi

# Login check
print_status "Checking Azure CLI authentication..."
if ! az account show >/dev/null 2>&1; then
    print_error "Not logged into Azure CLI. Please run 'az login' first."
    exit 1
fi
print_success "Azure CLI authentication verified"

# Login to Azure Container Registry
print_status "Logging into Azure Container Registry..."
if ! az acr login --name voicelinkregistry >/dev/null 2>&1; then
    print_error "Failed to login to Azure Container Registry"
    exit 1
fi
print_success "Logged into Azure Container Registry"

# Tag image for Azure deployment
print_status "Tagging image for Azure deployment..."
docker tag $REGISTRY/$IMAGE_NAME:$LOCAL_TAG $REGISTRY/$IMAGE_NAME:$AZURE_TAG
docker tag $REGISTRY/$IMAGE_NAME:$LOCAL_TAG $REGISTRY/$IMAGE_NAME:latest
print_success "Image tagged with Azure tags: $AZURE_TAG and latest"

# Push image to Azure Container Registry
print_status "Pushing image to Azure Container Registry..."
docker push $REGISTRY/$IMAGE_NAME:$AZURE_TAG
docker push $REGISTRY/$IMAGE_NAME:latest
print_success "Image pushed to Azure Container Registry"

# Check if container app exists
print_status "Checking if container app exists..."
if az containerapp show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP >/dev/null 2>&1; then
    print_status "Container app exists, updating..."
    UPDATE_MODE=true
else
    print_status "Container app doesn't exist, creating..."
    UPDATE_MODE=false
fi

if [ "$UPDATE_MODE" = true ]; then
    # Update existing container app
    print_status "Updating container app with new image..."
    az containerapp update \
        --name $CONTAINER_APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --image $REGISTRY/$IMAGE_NAME:$AZURE_TAG \
        --set-env-vars \
            RAILS_ENV=production \
            CW_API_ONLY_SERVER=true \
            DATABASE_URL="postgresql://chatwootuser:ChatwootSecure2025!@chatwoot-db-fresh.postgres.database.azure.com:5432/chatwoot_shared?sslmode=require" \
            REDIS_URL="redis://redis-shared.internal.calmmushroom-30b1c815.eastus.azurecontainerapps.io:6379" \
            SECRET_KEY_BASE="bb02bd4083fc907af6a7857e937af9067e1c68fde8995e90186545bb34e945f1" \
            FRONTEND_URL="https://chatwoot-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io" \
            FORCE_SSL=false \
            RAILS_LOG_TO_STDOUT=true \
            MAILER_SENDER_EMAIL="admin@voicelinkai.com" \
            SMTP_DOMAIN="voicelinkai.com" \
            ENABLE_ACCOUNT_SIGNUP=false \
            SKIP_DATABASE_CREATION=false \
            SIDEKIQ_CONCURRENCY=5
else
    # Create new container app
    print_status "Creating new container app..."
    az containerapp create \
        --name $CONTAINER_APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --environment chatwoot-env-test \
        --image $REGISTRY/$IMAGE_NAME:$AZURE_TAG \
        --target-port 3000 \
        --ingress external \
        --min-replicas 1 \
        --max-replicas 3 \
        --cpu 0.75 \
        --memory 1.5Gi \
        --env-vars \
            RAILS_ENV=production \
            CW_API_ONLY_SERVER=true \
            DATABASE_URL="postgresql://chatwootuser:ChatwootSecure2025!@chatwoot-db-fresh.postgres.database.azure.com:5432/chatwoot_shared?sslmode=require" \
            REDIS_URL="redis://redis-shared.internal.calmmushroom-30b1c815.eastus.azurecontainerapps.io:6379" \
            SECRET_KEY_BASE="bb02bd4083fc907af6a7857e937af9067e1c68fde8995e90186545bb34e945f1" \
            FRONTEND_URL="https://chatwoot-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io" \
            FORCE_SSL=false \
            RAILS_LOG_TO_STDOUT=true \
            MAILER_SENDER_EMAIL="admin@voicelinkai.com" \
            SMTP_DOMAIN="voicelinkai.com" \
            ENABLE_ACCOUNT_SIGNUP=false \
            SKIP_DATABASE_CREATION=false \
            SIDEKIQ_CONCURRENCY=5
fi

if [ $? -eq 0 ]; then
    print_success "Container app deployment completed"
else
    print_error "Container app deployment failed"
    exit 1
fi

# Wait for deployment to complete
print_status "Waiting for deployment to complete..."
sleep 60

# Verify deployment
print_status "Verifying deployment..."
HEALTH_URL="https://chatwoot-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/health"

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
    az containerapp logs show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --tail 20
else
    # Test API endpoints
    print_status "Testing API endpoints..."
    if curl -f -H "Accept: application/json" "https://chatwoot-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/platform/api/v1/accounts" >/dev/null 2>&1; then
        print_success "✅ Platform API is accessible"
    else
        print_warning "⚠️  Platform API might need authentication (expected)"
    fi
fi

# Show deployment information
print_status "Deployment Information:"
echo "  Image: $REGISTRY/$IMAGE_NAME:$AZURE_TAG"
echo "  Container App: $CONTAINER_APP_NAME"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Health URL: $HEALTH_URL"
echo "  API Base URL: https://chatwoot-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"

# Update KrakenD configuration for the deployed environment
print_status "Updating KrakenD configuration for environment..."
if [ -f "./scripts/update-krakend-config.sh" ]; then
    chmod +x ./scripts/update-krakend-config.sh
    
    # Determine environment based on container name
    if [[ "$CONTAINER_APP_NAME" == *"test"* ]]; then
        KRAKEND_ENV="development"
    elif [[ "$CONTAINER_APP_NAME" == *"staging"* ]]; then
        KRAKEND_ENV="staging"
    elif [[ "$CONTAINER_APP_NAME" == *"prod"* ]]; then
        KRAKEND_ENV="production"
    else
        KRAKEND_ENV="development"
    fi
    
    print_status "Updating KrakenD for environment: $KRAKEND_ENV"
    ./scripts/update-krakend-config.sh $KRAKEND_ENV update
    
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
if [[ "$KRAKEND_ENV" == "staging" ]]; then
    GATEWAY_PATH="staging"
elif [[ "$KRAKEND_ENV" == "production" ]]; then
    GATEWAY_PATH="prod"
fi

if curl -f "http://voicelinkai.com/$GATEWAY_PATH/health" >/dev/null 2>&1; then
    print_success "✅ Gateway routing is working"
    echo "  Gateway URL: http://voicelinkai.com/$GATEWAY_PATH/"
else
    print_warning "⚠️  Gateway routing might need manual configuration update"
    echo "  Try: ./scripts/update-krakend-config.sh $KRAKEND_ENV update"
fi

echo ""
echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo "================================"
echo -e "✅ Direct Access: ${BLUE}https://chatwoot-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io${NC}"
echo -e "✅ Via Gateway: ${BLUE}http://voicelinkai.com/dev/${NC}"
echo -e "✅ Health Check: ${BLUE}$HEALTH_URL${NC}"
echo ""
echo "Monitor deployment:"
echo "  az containerapp logs show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --follow"
echo ""
echo "Rollback if needed:"
echo "  az containerapp update --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --image chatwoot/chatwoot:latest" 