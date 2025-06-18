#!/bin/bash

# Configure SSL termination for existing Application Gateway
set -e

RESOURCE_GROUP="SM-Test"
APP_GW_NAME="voicelinkai-gateway-appgw"
PUBLIC_IP_NAME="voicelinkai-gateway-ip"

echo "🔐 Configuring SSL termination for VoiceLink AI Gateway..."

# Wait for Application Gateway to be ready
echo "⏳ Waiting for Application Gateway to be ready..."
while true; do
  STATUS=$(az network application-gateway show --resource-group $RESOURCE_GROUP --name $APP_GW_NAME --query "provisioningState" -o tsv)
  if [ "$STATUS" = "Succeeded" ]; then
    echo "✅ Application Gateway is ready!"
    break
  elif [ "$STATUS" = "Failed" ]; then
    echo "❌ Application Gateway creation failed!"
    exit 1
  else
    echo "⏳ Status: $STATUS - waiting 30 seconds..."
    sleep 30
  fi
done

# Generate self-signed certificate
echo "🔐 Generating self-signed SSL certificate..."
openssl req -x509 -newkey rsa:2048 -keyout gateway-key.pem -out gateway-cert.pem -days 365 -nodes \
  -subj "/C=US/ST=WA/L=Seattle/O=VoiceLink AI/CN=voicelinkai-gateway.eastus.cloudapp.azure.com"

# Convert to PFX format
openssl pkcs12 -export -out gateway-cert.pfx -inkey gateway-key.pem -in gateway-cert.pem -passout pass:

# Upload SSL certificate
echo "📤 Uploading SSL certificate..."
az network application-gateway ssl-cert create \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GW_NAME \
  --name ssl-certificate \
  --cert-file gateway-cert.pfx \
  --cert-password ""

# Add HTTPS frontend port
echo "🔧 Adding HTTPS frontend port..."
az network application-gateway frontend-port create \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GW_NAME \
  --name frontend-port-443 \
  --port 443

# Update backend pool to point to KrakenD container
echo "🎯 Updating backend pool..."
az network application-gateway address-pool update \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GW_NAME \
  --name appGatewayBackendPool \
  --servers voicelinkai-gateway.eastus.azurecontainer.io

# Update backend HTTP settings
echo "⚙️ Updating backend HTTP settings..."
az network application-gateway http-settings update \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GW_NAME \
  --name appGatewayBackendHttpSettings \
  --port 8080 \
  --protocol Http \
  --cookie-based-affinity Disabled \
  --timeout 30

# Create health probe
echo "🏥 Creating health probe..."
az network application-gateway probe create \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GW_NAME \
  --name health-probe \
  --protocol Http \
  --host-name-from-http-settings true \
  --path "/__health" \
  --interval 30 \
  --timeout 30 \
  --threshold 3

# Update backend settings to use health probe
echo "🔧 Updating backend settings with health probe..."
az network application-gateway http-settings update \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GW_NAME \
  --name appGatewayBackendHttpSettings \
  --probe health-probe

# Create HTTPS listener
echo "🎧 Creating HTTPS listener..."
az network application-gateway http-listener create \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GW_NAME \
  --name https-listener \
  --frontend-port frontend-port-443 \
  --ssl-cert ssl-certificate

# Create HTTPS routing rule
echo "🔀 Creating HTTPS routing rule..."
az network application-gateway rule create \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GW_NAME \
  --name https-routing-rule \
  --http-listener https-listener \
  --address-pool appGatewayBackendPool \
  --http-settings appGatewayBackendHttpSettings \
  --priority 200

# Create HTTP to HTTPS redirect
echo "↩️ Setting up HTTP to HTTPS redirect..."
az network application-gateway redirect-config create \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GW_NAME \
  --name http-to-https-redirect \
  --type Permanent \
  --target-listener https-listener \
  --include-path true \
  --include-query-string true

# Update the default HTTP rule to redirect
echo "🔄 Updating HTTP rule to redirect to HTTPS..."
az network application-gateway rule update \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GW_NAME \
  --name rule1 \
  --redirect-config http-to-https-redirect

# Get connection details
PUBLIC_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $PUBLIC_IP_NAME --query ipAddress -o tsv)
FQDN=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $PUBLIC_IP_NAME --query dnsSettings.fqdn -o tsv)

echo ""
echo "✅ SSL termination configuration completed!"
echo ""
echo "🌐 Access URLs:"
echo "   HTTPS: https://$FQDN"
echo "   Public IP: $PUBLIC_IP"
echo ""
echo "🧪 Test the widget config endpoint with HTTPS:"
echo "   curl -X POST \"https://$FQDN/api/v1/widget/config\" \\"
echo "        -H \"Content-Type: application/json\" \\"
echo "        -d '{\"website_token\": \"zEGFZ3658VdbbvkCTrpy8C5z\"}' \\"
echo "        -k"
echo ""
echo "📝 Note: Using self-signed certificate. Use -k flag with curl for testing."
echo "     For production, replace with a proper SSL certificate."

# Clean up certificate files
rm -f gateway-key.pem gateway-cert.pem gateway-cert.pfx

echo ""
echo "🎉 VoiceLink AI Gateway with SSL termination is ready!"
echo "🔒 The gateway now provides HTTPS access to the Chatwoot widget API!" 