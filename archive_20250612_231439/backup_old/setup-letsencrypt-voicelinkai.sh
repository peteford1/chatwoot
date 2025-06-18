#!/bin/bash
# Let's Encrypt SSL Certificate Setup for www.voicelinkai.com
# Date: June 5, 2025
# Purpose: Generate and configure SSL certificate for Azure deployment

set -e

# Configuration
DOMAIN="www.voicelinkai.com"
DOMAIN_ALT="voicelinkai.com"
EMAIL="admin@voicelinkai.com"  # Change this to your email
WEBROOT_PATH="/tmp/letsencrypt-webroot"
CERT_PATH="/etc/letsencrypt/live/$DOMAIN"
AZURE_RESOURCE_GROUP="SM-Test"
AZURE_GATEWAY_NAME="voicelinkai-gateway"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔒 Let's Encrypt SSL Setup for $DOMAIN${NC}"
echo "=================================================="

# Check if running as root (required for certbot)
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run as root (sudo)${NC}"
   echo "Usage: sudo bash setup-letsencrypt-voicelinkai.sh"
   exit 1
fi

# Step 1: Install certbot
echo -e "${YELLOW}📦 Installing certbot...${NC}"
if command -v apt-get &> /dev/null; then
    # Ubuntu/Debian
    apt-get update
    apt-get install -y certbot
elif command -v yum &> /dev/null; then
    # CentOS/RHEL
    yum install -y epel-release
    yum install -y certbot
elif command -v brew &> /dev/null; then
    # macOS
    brew install certbot
else
    echo -e "${RED}❌ Package manager not found. Please install certbot manually.${NC}"
    exit 1
fi

# Step 2: Check domain DNS
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

# Step 3: Create webroot directory
echo -e "${YELLOW}📁 Setting up webroot directory...${NC}"
mkdir -p $WEBROOT_PATH
chmod 755 $WEBROOT_PATH

# Step 4: Request certificate using webroot method
echo -e "${YELLOW}🔐 Requesting SSL certificate from Let's Encrypt...${NC}"
echo "Domain: $DOMAIN"
echo "Alt Domain: $DOMAIN_ALT"
echo "Email: $EMAIL"
echo ""

# Use certbot with webroot plugin
certbot certonly \
    --webroot \
    --webroot-path=$WEBROOT_PATH \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    --domains $DOMAIN,$DOMAIN_ALT \
    --non-interactive \
    --verbose

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ SSL Certificate generated successfully!${NC}"
else
    echo -e "${RED}❌ Certificate generation failed${NC}"
    echo ""
    echo "Common issues and solutions:"
    echo "1. Domain not pointing to your server"
    echo "2. Port 80 not accessible"
    echo "3. Firewall blocking HTTP traffic"
    echo "4. DNS not propagated yet"
    exit 1
fi

# Step 5: Display certificate information
echo -e "${BLUE}📋 Certificate Information:${NC}"
echo "Certificate: $CERT_PATH/fullchain.pem"
echo "Private Key: $CERT_PATH/privkey.pem"
echo "Certificate Chain: $CERT_PATH/chain.pem"
echo ""

# Step 6: Convert to PFX format for Azure
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

# Step 7: Create Azure CLI commands
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

# Step 8: Set up auto-renewal
echo -e "${YELLOW}🔄 Setting up automatic renewal...${NC}"
CRON_JOB="0 12 * * * /usr/bin/certbot renew --quiet --post-hook 'bash $(pwd)/upload-ssl-to-azure.sh'"

# Add to crontab if not already present
if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo -e "${GREEN}✅ Auto-renewal cron job added${NC}"
else
    echo -e "${YELLOW}⚠️  Auto-renewal cron job already exists${NC}"
fi

# Step 9: Create verification script
cat > verify-ssl.sh << EOF
#!/bin/bash
# SSL Certificate Verification Script

echo "🔍 Verifying SSL certificate for $DOMAIN..."

# Check certificate expiry
echo "Certificate expires:"
openssl x509 -in $CERT_PATH/fullchain.pem -noout -dates

# Check if site is accessible
echo ""
echo "Testing HTTPS connection:"
curl -I https://$DOMAIN --max-time 10

echo ""
echo "SSL verification complete!"
EOF

chmod +x verify-ssl.sh

# Final summary
echo ""
echo -e "${GREEN}🎉 Let's Encrypt SSL Setup Complete!${NC}"
echo "=============================================="
echo ""
echo -e "${BLUE}📁 Files created:${NC}"
echo "• SSL Certificate: $CERT_PATH/"
echo "• PFX Certificate: $PFX_PATH"
echo "• Azure upload script: upload-ssl-to-azure.sh"
echo "• Verification script: verify-ssl.sh"
echo ""
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo "1. Run: ./upload-ssl-to-azure.sh"
echo "2. Update your domain DNS to point to Azure Gateway IP"
echo "3. Test: ./verify-ssl.sh"
echo "4. Visit: https://$DOMAIN"
echo ""
echo -e "${BLUE}🔄 Auto-renewal:${NC}"
echo "• Certificates will auto-renew every 60 days"
echo "• Check with: sudo crontab -l"
echo ""
echo -e "${YELLOW}⚠️  Important:${NC}"
echo "• PFX Password: $PFX_PASSWORD"
echo "• Keep this password secure!"
echo "• Backup certificate files"

exit 0 