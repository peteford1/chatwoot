#!/bin/bash

echo "🔧 Fixing Cloudflare SSL configuration..."

# The issue: KrakenD is trying to handle SSL when Cloudflare already does it
# Solution: Remove TLS from KrakenD and let Cloudflare handle SSL termination

echo "📋 Current situation:"
echo "✅ Cloudflare is handling SSL for voicelinkai.com"
echo "❌ KrakenD is trying to handle SSL internally (causing handshake errors)"
echo "🎯 Solution: Remove TLS config from KrakenD"

echo ""
echo "🔄 Step 1: Update Cloudflare SSL settings..."
echo "In Cloudflare dashboard:"
echo "1. Go to SSL/TLS → Overview"
echo "2. Set SSL mode to 'Full' (not 'Full (strict)')"
echo "3. This allows Cloudflare to connect to your backend over HTTP"

echo ""
echo "🔄 Step 2: Update KrakenD configuration..."
echo "We need to deploy the SSL-free KrakenD configuration."

echo ""
echo "🔄 Step 3: Fix registry authentication..."
# Try to fix the registry authentication issue
echo "Attempting to fix Azure Container Registry authentication..."

# Get the container app's managed identity
PRINCIPAL_ID=$(az containerapp show --name voicelinkai-gateway-instance-v32 --resource-group SM-Test --query "identity.principalId" --output tsv)

if [ "$PRINCIPAL_ID" != "null" ] && [ -n "$PRINCIPAL_ID" ]; then
    echo "✅ Found managed identity: $PRINCIPAL_ID"
    
    # Grant AcrPull permission
    echo "Granting AcrPull permission..."
    az role assignment create \
        --assignee $PRINCIPAL_ID \
        --role AcrPull \
        --scope /subscriptions/535e2aa8-27e9-4d89-9208-be446ef89b87/resourceGroups/SM-Test/providers/Microsoft.ContainerRegistry/registries/chatwootregistry95290
    
    echo "✅ Registry permissions updated"
    
    # Now try to update the container
    echo "🔄 Updating KrakenD container with SSL-free configuration..."
    az containerapp update \
        --name voicelinkai-gateway-instance-v32 \
        --resource-group SM-Test \
        --image chatwootregistry95290.azurecr.io/krakend-no-ssl:latest
        
    if [ $? -eq 0 ]; then
        echo "✅ KrakenD updated successfully!"
        echo "🎉 SSL should now work with Cloudflare!"
    else
        echo "❌ Container update failed. Manual steps needed:"
        echo "1. Fix registry authentication in Azure portal"
        echo "2. Deploy krakend-no-ssl.json manually"
    fi
else
    echo "❌ No managed identity found. Creating one..."
    az containerapp identity assign \
        --name voicelinkai-gateway-instance-v32 \
        --resource-group SM-Test \
        --system-assigned
    
    echo "🔄 Please run this script again after identity is created."
fi

echo ""
echo "🧪 Test the fix:"
echo "curl -I https://voicelinkai.com/health"
echo ""
echo "📋 If still not working, check Cloudflare SSL mode:"
echo "- Should be 'Full' (not 'Full (strict)')"
echo "- Edge Certificates should be enabled"
echo "- Always Use HTTPS should be ON" 