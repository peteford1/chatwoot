#!/bin/bash

# Let's Encrypt SSL Certificate Setup Script
# Created: 2025-06-10 12:55:00
# Purpose: Generate free trusted SSL certificates using Let's Encrypt

DOMAIN="voicelinkai.com"
EMAIL="admin@voicelinkai.com"

echo "🔒 Setting up Let's Encrypt SSL Certificate for $DOMAIN"
echo "========================================================"

# Check if certbot is installed
if ! command -v certbot &> /dev/null; then
    echo "📦 Installing certbot..."
    
    # macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install certbot
    # Ubuntu/Debian
    elif command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y certbot
    # CentOS/RHEL
    elif command -v yum &> /dev/null; then
        sudo yum install -y certbot
    else
        echo "❌ Please install certbot manually"
        exit 1
    fi
fi

echo "🌐 Generating certificate for $DOMAIN..."

# Option 1: HTTP challenge (requires domain to point to your server)
echo "Option 1: HTTP Challenge"
echo "sudo certbot certonly --standalone -d $DOMAIN --email $EMAIL --agree-tos --non-interactive"

# Option 2: DNS challenge (manual)
echo ""
echo "Option 2: DNS Challenge (Manual)"
echo "sudo certbot certonly --manual --preferred-challenges dns -d $DOMAIN --email $EMAIL --agree-tos"

# Option 3: Wildcard certificate
echo ""
echo "Option 3: Wildcard Certificate"
echo "sudo certbot certonly --manual --preferred-challenges dns -d $DOMAIN -d *.$DOMAIN --email $EMAIL --agree-tos"

echo ""
echo "🎯 After getting certificates, they will be located at:"
echo "   Certificate: /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
echo "   Private Key: /etc/letsencrypt/live/$DOMAIN/privkey.pem"

echo ""
echo "📤 To upload to Azure Container Apps:"
echo "az containerapp env certificate upload \\"
echo "  --name chatwoot-env-test \\"
echo "  --resource-group SM-Test \\"
echo "  --certificate-file /etc/letsencrypt/live/$DOMAIN/fullchain.pem \\"
echo "  --certificate-key-file /etc/letsencrypt/live/$DOMAIN/privkey.pem \\"
echo "  --certificate-name letsencrypt-$DOMAIN"

echo ""
echo "🔄 Set up auto-renewal:"
echo "echo '0 12 * * * /usr/bin/certbot renew --quiet' | sudo crontab -" 