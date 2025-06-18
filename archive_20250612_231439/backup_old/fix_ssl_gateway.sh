#!/bin/bash

echo "🔧 Fixing SSL issues in KrakenD Gateway..."

# Build a new KrakenD image without SSL configuration
echo "📦 Building KrakenD image without SSL..."
docker build -t krakend-no-ssl:latest -f - . << 'EOF'
FROM devopsfaith/krakend:2.4
COPY krakend-no-ssl.json /etc/krakend/krakend.json
EXPOSE 8080
CMD ["run", "-c", "/etc/krakend/krakend.json"]
EOF

# Tag for Azure Container Registry
echo "🏷️ Tagging image for Azure Container Registry..."
docker tag krakend-no-ssl:latest chatwootregistry95290.azurecr.io/krakend-no-ssl:latest

# Push to Azure Container Registry
echo "📤 Pushing to Azure Container Registry..."
az acr login --name chatwootregistry95290
docker push chatwootregistry95290.azurecr.io/krakend-no-ssl:latest

# Update the container app with new image
echo "🔄 Updating KrakenD gateway container..."
az containerapp update \
  --name voicelinkai-gateway-instance-v32 \
  --resource-group SM-Test \
  --image chatwootregistry95290.azurecr.io/krakend-no-ssl:latest

echo "✅ SSL fix applied! The gateway should now work without SSL handshake errors."
echo "🌐 Test the gateway at: https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io/health" 