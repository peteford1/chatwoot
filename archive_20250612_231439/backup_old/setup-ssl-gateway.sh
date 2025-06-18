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

# 1. Create Virtual Network
echo "📡 Creating Virtual Network..."
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $VNET_NAME \
  --location $LOCATION \
  --address-prefixes 10.0.0.0/16 \
  --subnet-name gateway-subnet \
  --subnet-prefixes 10.0.1.0/24 \
  --tags purpose="VoiceLink AI Gateway Network" environment="production"

# Create backend subnet
echo "🔧 Creating backend subnet..."
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name backend-subnet \
  --address-prefixes 10.0.2.0/24

# 2. Create Public IP
echo "🌐 Creating Public IP..."
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name $PUBLIC_IP_NAME \
  --location $LOCATION \
  --allocation-method Static \
  --sku Standard \
  --dns-name voicelinkai-gateway \
  --tags purpose="VoiceLink AI Gateway Public IP" environment="production"

# 3. Generate self-signed certificate for testing
echo "🔐 Generating self-signed SSL certificate..."
openssl req -x509 -newkey rsa:2048 -keyout gateway-key.pem -out gateway-cert.pem -days 365 -nodes \
  -subj "/C=US/ST=WA/L=Seattle/O=VoiceLink AI/CN=voicelinkai-gateway.eastus.cloudapp.azure.com"

# Combine certificate and key into PFX format
openssl pkcs12 -export -out gateway-cert.pfx -inkey gateway-key.pem -in gateway-cert.pem -passout pass:

# Encode certificate to base64 for Azure
CERT_DATA=$(base64 -i gateway-cert.pfx | tr -d '\n')

# 4. Create Application Gateway
echo "🔒 Creating Application Gateway with SSL termination..."
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
  --cert-file gateway-cert.pfx \
  --cert-password "" \
  --tags purpose="VoiceLink AI Gateway SSL Termination" environment="production"

# 5. Add HTTPS frontend port
echo "🔧 Adding HTTPS frontend port..."
az network application-gateway frontend-port create \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GW_NAME \
  --name frontend-port-443 \
  --port 443

# 6. Add backend pool
echo "🎯 Configuring backend pool..."
az network application-gateway address-pool create \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GW_NAME \
  --name backend-pool \
  --servers voicelinkai-gateway.eastus.azurecontainer.io

# 7. Add HTTPS listener
echo "🎧 Creating HTTPS listener..."
az network application-gateway http-listener create \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GW_NAME \
  --name https-listener \
  --frontend-port frontend-port-443 \
  --ssl-cert $APP_GW_NAME

# 8. Add routing rule for HTTPS
echo "🔀 Creating HTTPS routing rule..."
az network application-gateway rule create \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GW_NAME \
  --name https-routing-rule \
  --http-listener https-listener \
  --address-pool backend-pool \
  --http-settings appGatewayBackendHttpSettings \
  --priority 200

# 9. Add HTTP to HTTPS redirect
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
az network application-gateway rule update \
  --resource-group $RESOURCE_GROUP \
  --gateway-name $APP_GW_NAME \
  --name rule1 \
  --redirect-config http-to-https-redirect

# 10. Get the public IP address
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