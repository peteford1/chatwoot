#!/bin/bash
# Let's Encrypt SSL Certificate Setup for www.voicelinkai.com (macOS Version - Fixed)
# Date: June 5, 2025
# Purpose: Generate and configure SSL certificate for Azure deployment on macOS

set -e

# Configuration
DOMAIN="www.voicelinkai.com"
DOMAIN_ALT="voicelinkai.com"
EMAIL="admin@voicelinkai.com"  # Change this to your email
WEBROOT_PATH="/tmp/letsencrypt-webroot"
CERT_PATH="/usr/local/etc/letsencrypt/live/$DOMAIN"
AZURE_RESOURCE_GROUP="SM-Test"
AZURE_GATEWAY_NAME="voicelinkai-gateway"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔒 Let's Encrypt SSL Setup for $DOMAIN (macOS - Fixed)${NC}"
echo "============================================================"

# Check if certbot is installed
if ! command -v certbot &> /dev/null; then
    echo -e "${RED}❌ certbot not found. Please install it first:${NC}"
    echo "brew install certbot"
    exit 1
fi

echo -e "${GREEN}✅ certbot found: $(which certbot)${NC}"

# Step 1: Check domain DNS
echo -e "${YELLOW}🌐 Checking DNS for $DOMAIN...${NC}"
if ! nslookup $DOMAIN > /dev/null 2>&1; then
    echo -e "${RED}❌ DNS lookup failed for $DOMAIN${NC}"
    echo "Please ensure:"
    echo "1. Domain is registered and DNS is configured"
    echo "2. Domain points to your Azure Application Gateway IP"
    echo "3. Wait a few minutes for DNS propagation"
    exit 1
fi

echo -e "${GREEN}✅ DNS lookup successful${NC}"

# Step 2: Create directories for certificates
echo -e "${YELLOW}📁 Setting up certificate directories...${NC}"
sudo mkdir -p /usr/local/etc/letsencrypt
sudo mkdir -p /usr/local/var/lib/letsencrypt
sudo mkdir -p /usr/local/var/log/letsencrypt

# Step 3: Generate certificate using DNS challenge
echo -e "${YELLOW}🔐 Requesting SSL certificate from Let's Encrypt...${NC}"
echo "Domain: $DOMAIN"
echo "Alt Domain: $DOMAIN_ALT"
echo "Email: $EMAIL"
echo ""
echo -e "${BLUE}Using DNS challenge method (manual verification required)${NC}"
echo ""
echo -e "${YELLOW}⚠️  You will need to add DNS TXT records as prompted by certbot!${NC}"

# Run certbot with correct flags for current version
sudo certbot certonly \
    --manual \
    --preferred-challenges dns \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    --domains $DOMAIN,$DOMAIN_ALT \
    --config-dir /usr/local/etc/letsencrypt \
    --work-dir /usr/local/var/lib/letsencrypt \
    --logs-dir /usr/local/var/log/letsencrypt

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ SSL Certificate generated successfully!${NC}"
else
    echo -e "${RED}❌ Certificate generation failed${NC}"
    echo ""
    echo "You can try using the staging server first to test:"
    echo "Add --staging flag to the certbot command above"
    exit 1
fi

# Update cert path for macOS
CERT_PATH="/usr/local/etc/letsencrypt/live/$DOMAIN"

# Step 4: Display certificate information
echo -e "${BLUE}📋 Certificate Information:${NC}"
echo "Certificate: $CERT_PATH/fullchain.pem"
echo "Private Key: $CERT_PATH/privkey.pem"
echo "Certificate Chain: $CERT_PATH/chain.pem"
echo ""

# Step 5: Convert to PFX format for Azure
echo -e "${YELLOW}🔄 Converting certificate to PFX format for Azure...${NC}"
PFX_PATH="/tmp/voicelinkai-ssl.pfx"
PFX_PASSWORD="VoiceLinkAI2025!"

openssl pkcs12 -export \
    -out $PFX_PATH \
    -inkey $CERT_PATH/privkey.pem \
    -in $CERT_PATH/fullchain.pem \
    -password pass:$PFX_PASSWORD

echo -e "${GREEN}✅ PFX certificate created: $PFX_PATH${NC}"
echo "PFX Password: $PFX_PASSWORD"

# Step 6: Create Azure CLI commands
echo -e "${YELLOW}🔧 Generating Azure CLI commands...${NC}"
cat > upload-ssl-to-azure.sh << EOF
#!/bin/bash
# Azure SSL Certificate Upload Commands
# Generated: $(date)

echo "🚀 Uploading SSL certificate to Azure..."

# Upload certificate to Azure Application Gateway
az network application-gateway ssl-cert create \\
    --resource-group $AZURE_RESOURCE_GROUP \\
    --gateway-name $AZURE_GATEWAY_NAME \\
    --name voicelinkai-ssl-cert \\
    --cert-file $PFX_PATH \\
    --cert-password $PFX_PASSWORD

# Update HTTPS listener to use the new certificate
az network application-gateway http-listener update \\
    --resource-group $AZURE_RESOURCE_GROUP \\
    --gateway-name $AZURE_GATEWAY_NAME \\
    --name httpsListener \\
    --ssl-cert voicelinkai-ssl-cert

echo "✅ SSL certificate uploaded and configured!"
echo "Your site should now be accessible at: https://$DOMAIN"
EOF

chmod +x upload-ssl-to-azure.sh

# Step 7: Create renewal script (macOS compatible)
echo -e "${YELLOW}🔄 Creating renewal script...${NC}"
SCRIPT_DIR="$(pwd)"
RENEWAL_SCRIPT="$SCRIPT_DIR/renew-ssl-macos.sh"

# Create renewal script
cat > $RENEWAL_SCRIPT << EOF
#!/bin/bash
# SSL Renewal Script for macOS
export PATH="/usr/local/bin:/opt/homebrew/bin:\$PATH"

echo "🔄 Checking certificate renewal..."

# Renew certificate
sudo certbot renew \\
    --config-dir /usr/local/etc/letsencrypt \\
    --work-dir /usr/local/var/lib/letsencrypt \\
    --logs-dir /usr/local/var/log/letsencrypt \\
    --quiet

# If renewal successful, update Azure
if [ \$? -eq 0 ]; then
    echo "✅ Certificate renewed successfully"
    
    # Convert to PFX
    openssl pkcs12 -export \\
        -out $PFX_PATH \\
        -inkey $CERT_PATH/privkey.pem \\
        -in $CERT_PATH/fullchain.pem \\
        -password pass:$PFX_PASSWORD
    
    # Upload to Azure
    bash $SCRIPT_DIR/upload-ssl-to-azure.sh
    
    echo "✅ Certificate uploaded to Azure"
else
    echo "ℹ️  No renewal needed or renewal failed"
fi
EOF

chmod +x $RENEWAL_SCRIPT

# Step 8: Create verification script
cat > verify-ssl.sh << EOF
#!/bin/bash
# SSL Certificate Verification Script

echo "🔍 Verifying SSL certificate for $DOMAIN..."

if [ -f "$CERT_PATH/fullchain.pem" ]; then
    # Check certificate expiry
    echo "Certificate expires:"
    openssl x509 -in $CERT_PATH/fullchain.pem -noout -dates
    
    echo ""
    echo "Certificate details:"
    openssl x509 -in $CERT_PATH/fullchain.pem -noout -subject
    
    echo ""
    echo "Certificate SAN (Subject Alternative Names):"
    openssl x509 -in $CERT_PATH/fullchain.pem -noout -text | grep -A1 "Subject Alternative Name"
else
    echo "❌ Certificate not found at $CERT_PATH/fullchain.pem"
fi

# Check if site is accessible
echo ""
echo "Testing HTTPS connection:"
curl -I https://$DOMAIN --max-time 10 2>/dev/null | head -1

echo ""
echo "SSL verification complete!"
EOF

chmod +x verify-ssl.sh

# Final summary
echo ""
echo -e "${GREEN}🎉 Let's Encrypt SSL Setup Complete! (macOS)${NC}"
echo "=============================================="
echo ""
echo -e "${BLUE}📁 Files created:${NC}"
echo "• SSL Certificate: $CERT_PATH/"
echo "• PFX Certificate: $PFX_PATH"
echo "• Azure upload script: upload-ssl-to-azure.sh"
echo "• Renewal script: $RENEWAL_SCRIPT"
echo "• Verification script: verify-ssl.sh"
echo ""
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo "1. Verify certificate: ./verify-ssl.sh"
echo "2. Upload to Azure: ./upload-ssl-to-azure.sh"
echo "3. Test website: https://$DOMAIN"
echo ""
echo -e "${BLUE}🔄 For auto-renewal:${NC}"
echo "• Test renewal: $RENEWAL_SCRIPT"
echo "• Add to cron: crontab -e"
echo "• Add line: 0 12 * * * $RENEWAL_SCRIPT"
echo ""
echo -e "${YELLOW}⚠️  Important Notes:${NC}"
echo "• PFX Password: $PFX_PASSWORD"
echo "• Certificate location: $CERT_PATH"
echo "• Backup certificate files regularly"
echo "• DNS TXT records can be removed after successful verification"

exit 0 