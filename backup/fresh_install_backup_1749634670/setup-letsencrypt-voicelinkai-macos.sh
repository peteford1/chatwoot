#!/bin/bash
# Let's Encrypt SSL Certificate Setup for www.voicelinkai.com (macOS Version)
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

echo -e "${BLUE}🔒 Let's Encrypt SSL Setup for $DOMAIN (macOS)${NC}"
echo "======================================================="

# Get the original user (before sudo)
if [ "$SUDO_USER" ]; then
    ORIGINAL_USER="$SUDO_USER"
else
    ORIGINAL_USER="$(whoami)"
fi

echo -e "${YELLOW}Running as: $(whoami), Original user: $ORIGINAL_USER${NC}"

# Step 1: Install certbot (as non-root user)
echo -e "${YELLOW}📦 Installing certbot...${NC}"
if ! command -v certbot &> /dev/null; then
    echo "Installing certbot via Homebrew (as $ORIGINAL_USER)..."
    # Run brew as the original user, not root
    sudo -u "$ORIGINAL_USER" brew install certbot
else
    echo -e "${GREEN}✅ certbot already installed${NC}"
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

# Step 4: Since we can't use webroot method easily on macOS, use manual method
echo -e "${YELLOW}🔐 Requesting SSL certificate from Let's Encrypt...${NC}"
echo "Domain: $DOMAIN"
echo "Alt Domain: $DOMAIN_ALT"
echo "Email: $EMAIL"
echo ""
echo -e "${BLUE}Note: Using manual method for macOS compatibility${NC}"

# Create a simple HTTP server for verification if needed
echo -e "${YELLOW}🌐 Starting temporary HTTP server for domain verification...${NC}"

# Check if port 80 is available locally
if lsof -i :80 >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Port 80 is in use. Let's Encrypt will need to verify domain ownership.${NC}"
    echo "Make sure your domain points to a server that can serve the verification files."
fi

# Use certbot with manual method and DNS challenge
echo -e "${YELLOW}🔑 Using DNS challenge method (recommended for macOS)...${NC}"

certbot certonly \
    --manual \
    --preferred-challenges dns \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    --domains $DOMAIN,$DOMAIN_ALT \
    --config-dir /usr/local/etc/letsencrypt \
    --work-dir /usr/local/var/lib/letsencrypt \
    --logs-dir /usr/local/var/log/letsencrypt \
    --manual-public-ip-logging-ok

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ SSL Certificate generated successfully!${NC}"
else
    echo -e "${RED}❌ Certificate generation failed${NC}"
    echo ""
    echo "Alternative: Try using the staging server first:"
    echo "certbot certonly --manual --preferred-challenges dns --staging --email $EMAIL --agree-tos --no-eff-email --domains $DOMAIN,$DOMAIN_ALT"
    exit 1
fi

# Update cert path for macOS
CERT_PATH="/usr/local/etc/letsencrypt/live/$DOMAIN"

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

# Step 8: Set up auto-renewal (macOS compatible)
echo -e "${YELLOW}🔄 Setting up automatic renewal...${NC}"
SCRIPT_DIR="$(pwd)"
RENEWAL_SCRIPT="$SCRIPT_DIR/renew-ssl-macos.sh"

# Create renewal script
cat > $RENEWAL_SCRIPT << EOF
#!/bin/bash
# SSL Renewal Script for macOS
export PATH="/usr/local/bin:\$PATH"

# Renew certificate
certbot renew \\
    --config-dir /usr/local/etc/letsencrypt \\
    --work-dir /usr/local/var/lib/letsencrypt \\
    --logs-dir /usr/local/var/log/letsencrypt \\
    --quiet

# If renewal successful, update Azure
if [ \$? -eq 0 ]; then
    # Convert to PFX
    openssl pkcs12 -export \\
        -out $PFX_PATH \\
        -inkey $CERT_PATH/privkey.pem \\
        -in $CERT_PATH/fullchain.pem \\
        -password pass:$PFX_PASSWORD
    
    # Upload to Azure
    bash $SCRIPT_DIR/upload-ssl-to-azure.sh
fi
EOF

chmod +x $RENEWAL_SCRIPT

# Add to launchd (macOS equivalent of cron)
PLIST_PATH="$HOME/Library/LaunchAgents/com.voicelinkai.ssl-renewal.plist"
cat > $PLIST_PATH << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.voicelinkai.ssl-renewal</string>
    <key>ProgramArguments</key>
    <array>
        <string>$RENEWAL_SCRIPT</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>12</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF

# Load the launchd job
sudo -u "$ORIGINAL_USER" launchctl load $PLIST_PATH 2>/dev/null || true

echo -e "${GREEN}✅ Auto-renewal configured via launchd${NC}"

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
echo -e "${GREEN}🎉 Let's Encrypt SSL Setup Complete! (macOS)${NC}"
echo "=============================================="
echo ""
echo -e "${BLUE}📁 Files created:${NC}"
echo "• SSL Certificate: $CERT_PATH/"
echo "• PFX Certificate: $PFX_PATH"
echo "• Azure upload script: upload-ssl-to-azure.sh"
echo "• Renewal script: $RENEWAL_SCRIPT"
echo "• Verification script: verify-ssl.sh"
echo "• LaunchAgent: $PLIST_PATH"
echo ""
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo "1. Run: ./upload-ssl-to-azure.sh"
echo "2. Test: ./verify-ssl.sh"
echo "3. Visit: https://$DOMAIN"
echo ""
echo -e "${BLUE}🔄 Auto-renewal:${NC}"
echo "• Configured via macOS LaunchAgent"
echo "• Runs daily at 12:00 PM"
echo "• Check with: launchctl list | grep ssl-renewal"
echo ""
echo -e "${YELLOW}⚠️  Important:${NC}"
echo "• PFX Password: $PFX_PASSWORD"
echo "• Certificate path: $CERT_PATH"
echo "• Keep backup of certificate files"

exit 0 