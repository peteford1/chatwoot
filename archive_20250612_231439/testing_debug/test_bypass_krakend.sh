#!/bin/bash

# Test script to verify bypassing KrakenD works
# This tests direct backend access vs domain access

echo "🚀 Testing KrakenD Bypass - Direct Backend Access"
echo "=================================================="

BACKEND_URL="https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
DOMAIN_URL="https://voicelinkai.com"
EMAIL="admin@voicelinkai.com"
PASSWORD="SuperAdmin123!"

echo ""
echo "1️⃣ Getting fresh authentication tokens from backend..."

# Get tokens from backend directly
RESPONSE=$(curl -s -X POST "${BACKEND_URL}/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}")

if [ $? -ne 0 ]; then
    echo "❌ Failed to connect to backend"
    exit 1
fi

# Extract tokens
ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.data.access_token // empty')
CLIENT=$(echo "$RESPONSE" | jq -r '.data.client // empty')
USER_UID=$(echo "$RESPONSE" | jq -r '.data.uid // empty')

if [ -z "$ACCESS_TOKEN" ] || [ -z "$CLIENT" ]; then
    echo "❌ Failed to get authentication tokens"
    echo "Response: $RESPONSE"
    exit 1
fi

echo "✅ Authentication successful!"
echo "   Access Token: ${ACCESS_TOKEN:0:20}..."
echo "   Client: ${CLIENT:0:20}..."
echo "   UID: $USER_UID"

echo ""
echo "2️⃣ Testing direct backend access..."

# Test direct backend
BACKEND_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\nTIME:%{time_total}" \
  -X GET "${BACKEND_URL}/api/v1/profile" \
  -H "access-token: $ACCESS_TOKEN" \
  -H "client: $CLIENT" \
  -H "uid: $USER_UID")

BACKEND_CODE=$(echo "$BACKEND_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BACKEND_TIME=$(echo "$BACKEND_RESPONSE" | grep "TIME:" | cut -d: -f2)
BACKEND_BODY=$(echo "$BACKEND_RESPONSE" | sed '/HTTP_CODE:/d' | sed '/TIME:/d')

echo "   Status Code: $BACKEND_CODE"
echo "   Response Time: ${BACKEND_TIME}s"

if [ "$BACKEND_CODE" = "200" ]; then
    echo "   ✅ Direct backend access works!"
    USER_NAME=$(echo "$BACKEND_BODY" | jq -r '.name // "Unknown"')
    echo "   👤 User: $USER_NAME"
else
    echo "   ❌ Direct backend access failed"
    echo "   Response: $BACKEND_BODY"
fi

echo ""
echo "3️⃣ Testing domain access (through KrakenD)..."

# Test through domain (KrakenD)
DOMAIN_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\nTIME:%{time_total}" \
  -X GET "${DOMAIN_URL}/api/v1/profile" \
  -H "access-token: $ACCESS_TOKEN" \
  -H "client: $CLIENT" \
  -H "uid: $USER_UID")

DOMAIN_CODE=$(echo "$DOMAIN_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
DOMAIN_TIME=$(echo "$DOMAIN_RESPONSE" | grep "TIME:" | cut -d: -f2)
DOMAIN_BODY=$(echo "$DOMAIN_RESPONSE" | sed '/HTTP_CODE:/d' | sed '/TIME:/d')

echo "   Status Code: $DOMAIN_CODE"
echo "   Response Time: ${DOMAIN_TIME}s"

if [ "$DOMAIN_CODE" = "200" ]; then
    echo "   ✅ Domain access works!"
    USER_NAME=$(echo "$DOMAIN_BODY" | jq -r '.name // "Unknown"')
    echo "   👤 User: $USER_NAME"
else
    echo "   ❌ Domain access failed (KrakenD issue)"
    echo "   Response: $DOMAIN_BODY"
fi

echo ""
echo "4️⃣ Testing DNS resolution..."

echo "   voicelinkai.com resolves to:"
nslookup voicelinkai.com | grep "Address:" | tail -n +2 | sed 's/^/     /'

echo "   Backend resolves to:"
nslookup chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io | grep "Address:" | tail -n +2 | sed 's/^/     /'

echo ""
echo "5️⃣ Test with host override (simulating DNS change)..."

# Test with host override to simulate DNS change
OVERRIDE_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\nTIME:%{time_total}" \
  -X GET "${DOMAIN_URL}/api/v1/profile" \
  --resolve "voicelinkai.com:443:51.8.58.201" \
  -H "access-token: $ACCESS_TOKEN" \
  -H "client: $CLIENT" \
  -H "uid: $USER_UID")

OVERRIDE_CODE=$(echo "$OVERRIDE_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
OVERRIDE_TIME=$(echo "$OVERRIDE_RESPONSE" | grep "TIME:" | cut -d: -f2)
OVERRIDE_BODY=$(echo "$OVERRIDE_RESPONSE" | sed '/HTTP_CODE:/d' | sed '/TIME:/d')

echo "   Status Code: $OVERRIDE_CODE"
echo "   Response Time: ${OVERRIDE_TIME}s"

if [ "$OVERRIDE_CODE" = "200" ]; then
    echo "   ✅ Host override works! DNS change will work"
    USER_NAME=$(echo "$OVERRIDE_BODY" | jq -r '.name // "Unknown"')
    echo "   👤 User: $USER_NAME"
else
    echo "   ⚠️  Host override failed - SSL certificate issue likely"
    echo "   Response: $OVERRIDE_BODY"
fi

echo ""
echo "📋 Summary"
echo "=========="
echo "Direct Backend:    $([ "$BACKEND_CODE" = "200" ] && echo "✅ Working" || echo "❌ Failed") (${BACKEND_TIME}s)"
echo "Through KrakenD:   $([ "$DOMAIN_CODE" = "200" ] && echo "✅ Working" || echo "❌ Failed") (${DOMAIN_TIME}s)" 
echo "Host Override:     $([ "$OVERRIDE_CODE" = "200" ] && echo "✅ Working" || echo "⚠️  SSL Issue")"

echo ""
if [ "$BACKEND_CODE" = "200" ] && [ "$DOMAIN_CODE" != "200" ]; then
    echo "🎯 RECOMMENDATION: Bypass KrakenD by updating DNS"
    echo ""
    echo "   1. Update Cloudflare DNS:"
    echo "      Type: A"
    echo "      Name: @"
    echo "      Content: 51.8.58.201"
    echo "      Proxy: 🟠 DNS only"
    echo ""
    echo "   2. Or create subdomain:"
    echo "      Type: CNAME"
    echo "      Name: direct"
    echo "      Content: chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
    echo ""
elif [ "$OVERRIDE_CODE" != "200" ]; then
    echo "⚠️  SSL Certificate needed for voicelinkai.com on backend"
    echo "   Consider using subdomain or backend URL directly"
fi

echo ""
echo "🔧 Next Steps:"
echo "1. Choose one of the bypass options from the instructions"
echo "2. Update DNS records in Cloudflare"
echo "3. Wait 5-10 minutes for DNS propagation"
echo "4. Test authentication again"
echo "" 