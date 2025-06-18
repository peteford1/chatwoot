#!/bin/bash
# DNS Verification Script for www.voicelinkai.com
# Run this BEFORE running the Let's Encrypt setup

DOMAIN="www.voicelinkai.com"
DOMAIN_ALT="voicelinkai.com"
EXPECTED_IP="your-azure-gateway-ip"  # Update this with your actual Azure Gateway IP

echo "🌐 DNS Verification for Let's Encrypt Setup"
echo "=========================================="
echo ""

# Function to check DNS resolution
check_dns() {
    local domain=$1
    echo "Checking: $domain"
    
    # Get IP address
    IP=$(nslookup $domain 2>/dev/null | grep -A 1 "Name:" | tail -n1 | awk '{print $2}')
    
    if [ -z "$IP" ]; then
        echo "❌ DNS lookup failed for $domain"
        return 1
    else
        echo "✅ $domain resolves to: $IP"
        
        # Test HTTP connectivity
        if curl -s --max-time 5 -I http://$domain > /dev/null 2>&1; then
            echo "✅ HTTP accessible on $domain (port 80)"
        else
            echo "⚠️  HTTP not accessible on $domain (port 80)"
            echo "   This is required for Let's Encrypt webroot verification"
        fi
        
        # Test HTTPS connectivity
        if curl -s --max-time 5 -I https://$domain > /dev/null 2>&1; then
            echo "✅ HTTPS accessible on $domain (port 443)"
        else
            echo "⚠️  HTTPS not accessible on $domain (current certificate may be invalid)"
        fi
        
        return 0
    fi
    echo ""
}

# Check main domain
echo "1. Primary Domain Check:"
check_dns $DOMAIN

echo ""
echo "2. Alternative Domain Check:"
check_dns $DOMAIN_ALT

echo ""
echo "3. Azure Gateway Status:"
GATEWAY_URL="https://voicelinkai-gateway.eastus.cloudapp.azure.com"
if curl -s --max-time 5 -I $GATEWAY_URL > /dev/null 2>&1; then
    echo "✅ Azure Gateway accessible: $GATEWAY_URL"
else
    echo "❌ Azure Gateway not accessible: $GATEWAY_URL"
fi

echo ""
echo "4. Requirements Checklist:"
echo "┌─────────────────────────────────────────────────────┐"
echo "│ Before running Let's Encrypt setup, ensure:        │"
echo "├─────────────────────────────────────────────────────┤"
echo "│ ✓ Domain DNS points to your Azure Gateway IP       │"
echo "│ ✓ Azure Gateway is running and accessible          │"
echo "│ ✓ Port 80 (HTTP) is open and accessible            │"
echo "│ ✓ You have admin access to your server/container   │"
echo "│ ✓ Domain has been registered and is active         │"
echo "└─────────────────────────────────────────────────────┘"

echo ""
echo "🚀 If all checks pass, run: sudo ./setup-letsencrypt-voicelinkai.sh"
echo ""

# Get Azure Gateway IP for reference
echo "💡 To find your Azure Gateway IP:"
echo "   az network public-ip show --resource-group SM-Test --name voicelinkai-gateway-ip --query ipAddress" 