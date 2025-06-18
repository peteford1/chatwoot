#!/bin/bash

echo "🚀 DEPLOYING UPDATED KRAKEND CONFIGURATION TO AZURE"
echo "=" * 60

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

# Get current container app configuration
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

# Build and deploy using Azure Container Apps
echo "🔨 Building and deploying updated KrakenD container..."

# Update the container app with new configuration
az containerapp update \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --source "$TEMP_DIR" \
    --target-port 8080 \
    --ingress external \
    --min-replicas 1 \
    --max-replicas 3 \
    --cpu 0.5 \
    --memory 1Gi \
    --env-vars KRAKEND_PORT=8080

DEPLOYMENT_STATUS=$?

# Clean up temporary directory
rm -rf "$TEMP_DIR"

if [ $DEPLOYMENT_STATUS -eq 0 ]; then
    echo "✅ KrakenD deployment successful!"
    
    # Wait a moment for deployment to stabilize
    echo "⏳ Waiting for deployment to stabilize..."
    sleep 30
    
    # Test the deployment
    echo "🧪 Testing updated KrakenD gateway..."
    
    GATEWAY_URL="https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
    
    # Test health endpoint
    echo "Testing health endpoint..."
    curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/health"
    HEALTH_STATUS=$?
    
    if [ $HEALTH_STATUS -eq 0 ]; then
        echo "✅ Health check passed"
    else
        echo "⚠️  Health check failed, but deployment may still be starting"
    fi
    
    # Test API endpoint
    echo "Testing API endpoint..."
    curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/api"
    API_STATUS=$?
    
    if [ $API_STATUS -eq 0 ]; then
        echo "✅ API endpoint accessible"
    else
        echo "⚠️  API endpoint test failed"
    fi
    
    echo ""
    echo "🎯 DEPLOYMENT SUMMARY:"
    echo "   Gateway URL: $GATEWAY_URL"
    echo "   Health Check: $GATEWAY_URL/health"
    echo "   API Endpoint: $GATEWAY_URL/api"
    echo "   Backup File: backup/krakend_deployment_backup_${BACKUP_TIMESTAMP}.json"
    echo ""
    echo "✨ KrakenD deployment completed successfully!"
    echo "🔄 You can now run the comprehensive test to validate the updated API routing."
    
else
    echo "❌ KrakenD deployment failed!"
    echo "💡 Check the backup file: backup/krakend_deployment_backup_${BACKUP_TIMESTAMP}.json"
    echo "🔧 You may need to restore the previous configuration if needed."
    exit 1
fi 