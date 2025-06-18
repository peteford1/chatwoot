#!/bin/bash

echo "🚀 DEPLOYING UPDATED KRAKEND CONFIGURATION TO AZURE"
echo "=================================================="

# Configuration
RESOURCE_GROUP="SM-Test"
CONTAINER_APP_NAME="voicelinkai-gateway-instance-v32"
KRAKEND_CONFIG_FILE="krakend.json"

# Check if config file exists
if [ ! -f "$KRAKEND_CONFIG_FILE" ]; then
    echo "❌ Error: $KRAKEND_CONFIG_FILE not found!"
    exit 1
fi

echo "✅ Found KrakenD configuration file: $KRAKEND_CONFIG_FILE"

# Create backup of current deployment
BACKUP_TIMESTAMP=$(date +%s)
echo "📦 Creating backup of current deployment..."

az containerapp show \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --output json > "backup/krakend_deployment_backup_${BACKUP_TIMESTAMP}.json"

if [ $? -eq 0 ]; then
    echo "✅ Backup created: backup/krakend_deployment_backup_${BACKUP_TIMESTAMP}.json"
else
    echo "⚠️  Warning: Could not create backup, continuing with deployment..."
fi

# Create a temporary directory for deployment files
TEMP_DIR=$(mktemp -d)
echo "📁 Using temporary directory: $TEMP_DIR"

# Copy the KrakenD config to temp directory
cp "$KRAKEND_CONFIG_FILE" "$TEMP_DIR/"

# Create Dockerfile for KrakenD with updated config
cat > "$TEMP_DIR/Dockerfile" << 'EOF'
FROM devopsfaith/krakend:2.4.1

# Copy the configuration file
COPY krakend.json /etc/krakend/krakend.json

# Expose port 8080
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Start KrakenD
CMD ["krakend", "run", "-c", "/etc/krakend/krakend.json"]
EOF

echo "✅ Created Dockerfile with updated configuration"

# Build the Docker image locally first
echo "🔨 Building Docker image locally..."
cd "$TEMP_DIR"

# Build the image
docker build -t krakend-updated:latest .

if [ $? -ne 0 ]; then
    echo "❌ Docker build failed!"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "✅ Docker image built successfully"

# Get the current container app environment
echo "📋 Getting container app environment..."
ENVIRONMENT=$(az containerapp show --name "$CONTAINER_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "properties.environmentId" --output tsv | xargs basename)

if [ -z "$ENVIRONMENT" ]; then
    echo "❌ Could not determine container app environment"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "✅ Found environment: $ENVIRONMENT"

# Update the container app using simplified approach
echo "🚀 Updating container app..."

# Use az containerapp up with minimal parameters
az containerapp up \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ENVIRONMENT" \
    --source .

DEPLOYMENT_STATUS=$?

# Return to original directory and clean up
cd - > /dev/null
rm -rf "$TEMP_DIR"

if [ $DEPLOYMENT_STATUS -eq 0 ]; then
    echo "✅ KrakenD deployment successful!"
    
    # Wait a moment for deployment to stabilize
    echo "⏳ Waiting for deployment to stabilize..."
    sleep 60
    
    # Test the deployment
    echo "🧪 Testing updated KrakenD gateway..."
    
    GATEWAY_URL="https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
    
    # Test health endpoint
    echo "Testing health endpoint..."
    HEALTH_RESPONSE=$(curl -s -w "%{http_code}" "$GATEWAY_URL/health" || echo "FAILED")
    echo "Health response: $HEALTH_RESPONSE"
    
    # Test API endpoint
    echo "Testing API endpoint..."
    API_RESPONSE=$(curl -s -w "%{http_code}" "$GATEWAY_URL/api" || echo "FAILED")
    echo "API response: $API_RESPONSE"
    
    # Test a specific API endpoint that was failing before
    echo "Testing contacts API endpoint..."
    CONTACTS_RESPONSE=$(curl -s -w "%{http_code}" "$GATEWAY_URL/api/v1/accounts/1/contacts" || echo "FAILED")
    echo "Contacts API response: $CONTACTS_RESPONSE"
    
    echo ""
    echo "🎯 DEPLOYMENT SUMMARY:"
    echo "   Gateway URL: $GATEWAY_URL"
    echo "   Health Check: $GATEWAY_URL/health"
    echo "   API Endpoint: $GATEWAY_URL/api"
    echo "   Contacts API: $GATEWAY_URL/api/v1/accounts/1/contacts"
    echo "   Backup File: backup/krakend_deployment_backup_${BACKUP_TIMESTAMP}.json"
    echo ""
    echo "✨ KrakenD deployment completed successfully!"
    echo "🔄 You can now run the comprehensive test to validate the updated API routing:"
    echo "   ruby comprehensive_api_test.rb"
    
else
    echo "❌ KrakenD deployment failed!"
    echo "💡 Check the backup file: backup/krakend_deployment_backup_${BACKUP_TIMESTAMP}.json"
    echo "🔧 You may need to restore the previous configuration if needed."
    exit 1
fi 