#!/bin/bash

# Setup SSL Gateway for VoiceLink AI Gateway
# This script creates Application Gateway with SSL termination

set -e

RESOURCE_GROUP="SM-Test"
LOCATION="eastus"
VNET_NAME="voicelinkai-vnet"
PUBLIC_IP_NAME="voicelinkai-gateway-ip"
APP_GW_NAME="voicelinkai-gateway-appgw"

echo "🚀 Setting up VoiceLink AI Gateway with SSL termination..."

# Check if VNet exists, if not create it
if ! az network vnet show --resource-group $RESOURCE_GROUP --name $VNET_NAME &>/dev/null; then
  echo "📡 Creating Virtual Network..."
  az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $VNET_NAME \
    --location $LOCATION \
    --address-prefixes 10.0.0.0/16 \
    --subnet-name gateway-subnet \
    --subnet-prefixes 10.0.1.0/24 \
    --tags purpose="VoiceLink AI Gateway Network" environment="production"
fi

# Check if Public IP exists, if not create it
if ! az network public-ip show --resource-group $RESOURCE_GROUP --name $PUBLIC_IP_NAME &>/dev/null; then
  echo "🌐 Creating Public IP..."
  az network public-ip create \
    --resource-group $RESOURCE_GROUP \
    --name $PUBLIC_IP_NAME \
    --location $LOCATION \
    --allocation-method Static \
    --sku Standard \
    --dns-name voicelinkai-gateway \
    --tags purpose="VoiceLink AI Gateway Public IP" environment="production"
fi

# Generate self-signed certificate for testing
echo "🔐 Generating self-signed SSL certificate..."
openssl req -x509 -newkey rsa:2048 -keyout gateway-key.pem -out gateway-cert.pem -days 365 -nodes \
  -subj "/C=US/ST=WA/L=Seattle/O=VoiceLink AI/CN=voicelinkai-gateway.eastus.cloudapp.azure.com"

# Combine certificate and key into PFX format
openssl pkcs12 -export -out gateway-cert.pfx -inkey gateway-key.pem -in gateway-cert.pem -passout pass:

# Create Application Gateway with HTTP listener first
echo "🔒 Creating Application Gateway..."
az network application-gateway create \
  --resource-group $RESOURCE_GROUP \
  --name $APP_GW_NAME \
  --location $LOCATION \
  --vnet-name $VNET_NAME \
  --subnet gateway-subnet \
  --public-ip-address $PUBLIC_IP_NAME \
  --sku Standard_v2 \
  --capacity 1 \
  --http-settings-cookie-based-affinity Disabled \
  --http-settings-port 8080 \
  --http-settings-protocol Http \
  --frontend-port 80 \
  --tags purpose="VoiceLink AI Gateway SSL Termination" environment="production"

# Upload SSL certificate
echo "🔐 Adding SSL certificate..."
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

# Create backend pool pointing to KrakenD container
echo "🎯 Creating backend pool..."
az network application-gateway address-pool create \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GW_NAME \
  --name backend-pool \
  --servers voicelinkai-gateway.eastus.azurecontainer.io

# Create HTTP settings for backend
echo "⚙️ Creating backend HTTP settings..."
az network application-gateway http-settings create \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GW_NAME \
  --name backend-http-settings \
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

# Update backend HTTP settings to use health probe
echo "🔧 Updating backend settings with health probe..."
az network application-gateway http-settings update \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GW_NAME \
  --name backend-http-settings \
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
  --address-pool backend-pool \
  --http-settings backend-http-settings \
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

# Get the public IP address and FQDN
echo "📋 Getting Application Gateway details..."
PUBLIC_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $PUBLIC_IP_NAME --query ipAddress -o tsv)
FQDN=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $PUBLIC_IP_NAME --query dnsSettings.fqdn -o tsv)

echo ""
echo "✅ Application Gateway deployment completed!"
echo ""
echo "🌐 Access URLs:"
echo "   HTTPS: https://$FQDN"
echo "   Public IP: $PUBLIC_IP"
echo ""
echo "🧪 Test the widget config endpoint:"
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