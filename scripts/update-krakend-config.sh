#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-"development"}
KRAKEND_CONFIG_DIR="./krakend/environments"
REGISTRY="voicelinkregistry.azurecr.io"
RESOURCE_GROUP="SM-Test"

echo -e "${BLUE}🔧 KrakenD Configuration Manager${NC}"
echo "=================================="

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate environment
case $ENVIRONMENT in
    "development"|"dev")
        ENV="dev"
        BACKEND_URL="https://chatwoot-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
        CONTAINER_NAME="chatwoot-test"
        ;;
    "staging"|"stage")
        ENV="staging"
        BACKEND_URL="https://chatwoot-staging.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
        CONTAINER_NAME="chatwoot-staging"
        ;;
    "production"|"prod")
        ENV="prod"
        BACKEND_URL="https://chatwoot-prod.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
        CONTAINER_NAME="chatwoot-prod"
        ;;
    *)
        print_error "Invalid environment: $ENVIRONMENT"
        echo "Valid environments: development, staging, production"
        exit 1
        ;;
esac

print_status "Configuring KrakenD for environment: $ENV"
print_status "Backend URL: $BACKEND_URL"

# Function to update KrakenD configuration
update_krakend_config() {
    local config_file="$KRAKEND_CONFIG_DIR/multi-env/krakend.json"
    local temp_file="/tmp/krakend-updated.json"
    
    print_status "Updating KrakenD configuration..."
    
    # Check if backend is healthy before updating config
    print_status "Checking backend health: $BACKEND_URL/health"
    if curl -f "$BACKEND_URL/health" >/dev/null 2>&1; then
        print_success "✅ Backend is healthy"
    else
        print_error "❌ Backend is not responding at $BACKEND_URL/health"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Update the configuration using jq
    if ! command -v jq >/dev/null 2>&1; then
        print_error "jq is required but not installed. Please install jq first."
        exit 1
    fi
    
    # Create updated configuration
    jq --arg backend_url "$BACKEND_URL" --arg env "$ENV" '
        # Update all endpoints that match the environment
        .endpoints |= map(
            if .endpoint | test("^/\($env)/") then
                .backend[0].host = [$backend_url]
            else . end
        ) |
        # Update health endpoint if this is production
        if $env == "prod" then
            .endpoints |= map(
                if .endpoint == "/health" then
                    .backend[0].host = [$backend_url]
                else . end
            )
        else . end |
        # Update metadata
        .extra_config.metadata = {
            "last_updated": now | strftime("%Y-%m-%d %H:%M:%S UTC"),
            "updated_for_environment": $env,
            "backend_url": $backend_url
        }
    ' "$config_file" > "$temp_file"
    
    # Validate the JSON
    if jq empty "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$config_file"
        print_success "✅ KrakenD configuration updated successfully"
    else
        print_error "❌ Generated JSON is invalid"
        rm -f "$temp_file"
        exit 1
    fi
}

# Function to build and deploy KrakenD
deploy_krakend() {
    print_status "Building and deploying KrakenD with updated configuration..."
    
    # Build new KrakenD image
    local image_tag="$REGISTRY/krakend-gateway:config-update-$(date +%Y%m%d-%H%M%S)"
    
    docker build -t "$image_tag" ./krakend/
    
    if [ $? -eq 0 ]; then
        print_success "✅ KrakenD image built successfully"
    else
        print_error "❌ Failed to build KrakenD image"
        exit 1
    fi
    
    # Push to registry
    print_status "Pushing KrakenD image to registry..."
    docker push "$image_tag"
    
    if [ $? -eq 0 ]; then
        print_success "✅ KrakenD image pushed to registry"
    else
        print_error "❌ Failed to push KrakenD image"
        exit 1
    fi
    
    # Update Azure Container App
    print_status "Updating KrakenD container app..."
    az containerapp update \
        --name voicelinkai-gateway-instance-v32 \
        --resource-group SM-Test \
        --image "$image_tag"
    
    if [ $? -eq 0 ]; then
        print_success "✅ KrakenD container app updated"
    else
        print_error "❌ Failed to update KrakenD container app"
        exit 1
    fi
    
    # Wait for deployment
    print_status "Waiting for KrakenD deployment to complete..."
    sleep 30
    
    # Test the gateway
    print_status "Testing KrakenD gateway..."
    if curl -f "http://voicelinkai.com/__health" >/dev/null 2>&1; then
        print_success "✅ KrakenD gateway is responding"
    else
        print_error "❌ KrakenD gateway is not responding"
    fi
    
    # Test environment-specific routing
    print_status "Testing environment routing..."
    if curl -f "http://voicelinkai.com/$ENV/health" >/dev/null 2>&1; then
        print_success "✅ Environment routing is working for /$ENV/"
    else
        print_error "❌ Environment routing failed for /$ENV/"
    fi
}

# Function to show current configuration
show_config() {
    print_status "Current KrakenD Configuration Summary:"
    echo "  Environment: $ENV"
    echo "  Backend URL: $BACKEND_URL"
    echo "  Container: $CONTAINER_NAME"
    echo "  Gateway URL: http://voicelinkai.com/$ENV/"
    echo ""
    
    print_status "Testing current configuration..."
    echo "  Backend Health: $(curl -s -o /dev/null -w '%{http_code}' $BACKEND_URL/health 2>/dev/null || echo 'FAILED')"
    echo "  Gateway Health: $(curl -s -o /dev/null -w '%{http_code}' http://voicelinkai.com/__health 2>/dev/null || echo 'FAILED')"
    echo "  Environment Route: $(curl -s -o /dev/null -w '%{http_code}' http://voicelinkai.com/$ENV/health 2>/dev/null || echo 'FAILED')"
}

# Main execution
case "${2:-update}" in
    "show"|"status")
        show_config
        ;;
    "config-only")
        update_krakend_config
        print_success "✅ Configuration updated (not deployed)"
        ;;
    "update"|"deploy")
        update_krakend_config
        deploy_krakend
        show_config
        ;;
    *)
        print_error "Invalid action. Use: show, config-only, update, or deploy"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}🎉 KrakenD Configuration Management Complete!${NC}"
echo "============================================="
echo "Usage examples:"
echo "  ./scripts/update-krakend-config.sh development update"
echo "  ./scripts/update-krakend-config.sh staging deploy"
echo "  ./scripts/update-krakend-config.sh production show" 