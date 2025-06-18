#!/bin/bash

echo "🔐 Setting up SSL for voicelinkai.com using Azure Container Apps..."

# Step 1: Add custom domain
echo "📝 Adding custom domain to container app..."
az containerapp hostname add \
  --name voicelinkai-gateway-instance-v32 \
  --resource-group SM-Test \
  --hostname voicelinkai.com

# Step 2: Get verification info
echo "🔍 Getting DNS verification requirements..."
az containerapp hostname show \
  --name voicelinkai-gateway-instance-v32 \
  --resource-group SM-Test \
  --hostname voicelinkai.com

echo ""
echo "📋 NEXT STEPS:"
echo "1. Add CNAME record: voicelinkai.com → voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
echo "2. Add the TXT verification record shown above to your DNS"
echo "3. Wait for DNS propagation (5-10 minutes)"
echo "4. Run this command to bind the certificate:"
echo "   az containerapp hostname bind --name voicelinkai-gateway-instance-v32 --resource-group SM-Test --hostname voicelinkai.com --environment-certificate-id managed"
echo ""
echo "🔧 After SSL is working, deploy the SSL-free KrakenD configuration to remove TLS errors." 