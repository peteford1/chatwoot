#!/bin/bash

# Deploy Routing Fix Script
# Created: 2025-06-12 10:50:00
# Purpose: Build and deploy container with ActionCable and routing fixes

set -e

echo "🔧 Starting Chatwoot Routing Fix Deployment..."

# Build the new container with routing fixes
echo "📦 Building container with routing fixes..."
docker build -f Dockerfile.azure-routing-fix -t chatwoot-routing-fix:latest .

# Tag for Azure Container Registry
echo "🏷️ Tagging container for Azure..."
docker tag chatwoot-routing-fix:latest chatwootregistry95290.azurecr.io/chatwoot-routing-fix:latest

# Push to Azure Container Registry
echo "⬆️ Pushing to Azure Container Registry..."
az acr login --name chatwootregistry95290
docker push chatwootregistry95290.azurecr.io/chatwoot-routing-fix:latest

# Update the container app with new image
echo "🚀 Updating Azure Container App..."
az containerapp update \
  --name chatwoot-backend-test \
  --resource-group SM-Test \
  --image chatwootregistry95290.azurecr.io/chatwoot-routing-fix:latest

echo "✅ Deployment complete!"
echo ""
echo "🔍 Testing endpoints..."
echo "Direct backend: https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/cable"
echo "Through gateway: https://voicelinkai.com/cable"
echo ""
echo "⏳ Wait 2-3 minutes for the deployment to complete, then test the endpoints." 