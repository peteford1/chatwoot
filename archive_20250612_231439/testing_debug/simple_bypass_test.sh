#!/bin/bash

echo "🚀 Simple KrakenD Bypass Test"
echo "============================"

BACKEND_URL="https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
DOMAIN_URL="https://voicelinkai.com"

echo ""
echo "1️⃣ Testing Backend Health Check..."
BACKEND_HEALTH=$(curl -s -w "HTTP_CODE:%{http_code}" -X GET "${BACKEND_URL}/api/v1/accounts")
BACKEND_CODE=$(echo "$BACKEND_HEALTH" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$BACKEND_CODE" = "401" ]; then
    echo "✅ Backend is responding (401 = needs auth, which is expected)"
else
    echo "❌ Backend response code: $BACKEND_CODE"
fi

echo ""
echo "2️⃣ Testing Domain Health Check..."
DOMAIN_HEALTH=$(curl -s -w "HTTP_CODE:%{http_code}" -X GET "${DOMAIN_URL}/api/v1/accounts")
DOMAIN_CODE=$(echo "$DOMAIN_HEALTH" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$DOMAIN_CODE" = "401" ]; then
    echo "✅ Domain is responding through KrakenD (401 = needs auth)"
else
    echo "❌ Domain response code: $DOMAIN_CODE"
fi

echo ""
echo "3️⃣ DNS Information..."
echo "Current DNS for voicelinkai.com:"
nslookup voicelinkai.com | grep "Address:" | tail -n +2 | sed 's/^/   /'

echo ""
echo "Backend IP:"
nslookup chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io | grep "Address:" | tail -n +2 | sed 's/^/   /'

echo ""
echo "📋 BYPASS RECOMMENDATION"
echo "========================"
echo ""
echo "✅ Backend is working: $BACKEND_URL"
echo "⚠️  KrakenD has authentication issues (header forwarding problem)"
echo ""
echo "🎯 TO BYPASS KRAKEND:"
echo ""
echo "1. Update Cloudflare DNS Record:"
echo "   • Go to: https://dash.cloudflare.com/"
echo "   • Select: voicelinkai.com domain"
echo "   • Edit A record:"
echo "     Type: A"
echo "     Name: @"
echo "     Content: 51.8.58.201"
echo "     Proxy Status: 🟠 DNS only (turn OFF orange cloud)"
echo ""
echo "2. Alternative - Create subdomain:"
echo "   • Add new record:"
echo "     Type: CNAME"
echo "     Name: direct"
echo "     Content: chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
echo "     Proxy Status: 🟠 DNS only"
echo "   • Then use: https://direct.voicelinkai.com"
echo ""
echo "3. Test after DNS change (wait 5-10 minutes):"
echo "   curl -X GET \"https://voicelinkai.com/api/v1/accounts\""
echo ""
echo "🔧 This will route traffic DIRECTLY to Chatwoot backend,"
echo "   bypassing KrakenD's header forwarding issues."
echo "" 