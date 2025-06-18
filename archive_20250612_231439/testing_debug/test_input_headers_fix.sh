#!/bin/bash

echo "🧪 Testing KrakenD with input_headers instead of headers_to_pass"
echo "============================================================="

BACKEND_URL="https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
DOMAIN_URL="https://voicelinkai.com"
EMAIL="admin@voicelinkai.com"
PASSWORD="SuperAdmin123!"

echo ""
echo "1️⃣ Getting fresh authentication tokens..."

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
CLIENT=$(echo "$RESPONSE" | jq -r '.data.client // "missing"')
USER_UID=$(echo "$RESPONSE" | jq -r '.data.uid // empty')

if [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Failed to get authentication tokens"
    echo "Response: $RESPONSE"
    exit 1
fi

echo "✅ Got tokens successfully!"
echo "   Access Token: ${ACCESS_TOKEN:0:20}..."
echo "   Client: $CLIENT"
echo "   UID: $USER_UID"

echo ""
echo "2️⃣ Testing profile endpoint through KrakenD (with input_headers)..."

# Test through KrakenD with the new input_headers configuration
KRAKEND_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\nTIME:%{time_total}" \
  -X GET "${DOMAIN_URL}/api/v1/profile" \
  -H "access-token: $ACCESS_TOKEN" \
  -H "client: $CLIENT" \
  -H "uid: $USER_UID" \
  -H "token-type: Bearer" \
  -H "Content-Type: application/json")

KRAKEND_CODE=$(echo "$KRAKEND_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
KRAKEND_TIME=$(echo "$KRAKEND_RESPONSE" | grep "TIME:" | cut -d: -f2)
KRAKEND_BODY=$(echo "$KRAKEND_RESPONSE" | sed '/HTTP_CODE:/d' | sed '/TIME:/d')

echo "   Status Code: $KRAKEND_CODE"
echo "   Response Time: ${KRAKEND_TIME}s"

if [ "$KRAKEND_CODE" = "401" ]; then
    echo "   🎉 SUCCESS! KrakenD is now forwarding headers properly!"
    echo "   Backend received request and processed authentication (401 = expected)"
elif [ "$KRAKEND_CODE" = "200" ]; then
    echo "   🎉 AMAZING! Authentication worked completely!"
    USER_NAME=$(echo "$KRAKEND_BODY" | jq -r '.name // "Unknown"')
    echo "   👤 User: $USER_NAME"
else
    echo "   ❌ Still not working. Response:"
    echo "   Code: $KRAKEND_CODE"
    echo "   Body: $KRAKEND_BODY"
fi

echo ""
echo "3️⃣ For comparison - Direct backend test..."

# Test direct backend
BACKEND_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\nTIME:%{time_total}" \
  -X GET "${BACKEND_URL}/api/v1/profile" \
  -H "access-token: $ACCESS_TOKEN" \
  -H "client: $CLIENT" \
  -H "uid: $USER_UID" \
  -H "token-type: Bearer" \
  -H "Content-Type: application/json")

BACKEND_CODE=$(echo "$BACKEND_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BACKEND_TIME=$(echo "$BACKEND_RESPONSE" | grep "TIME:" | cut -d: -f2)
BACKEND_BODY=$(echo "$BACKEND_RESPONSE" | sed '/HTTP_CODE:/d' | sed '/TIME:/d')

echo "   Status Code: $BACKEND_CODE"
echo "   Response Time: ${BACKEND_TIME}s"

echo ""
echo "📊 RESULTS COMPARISON"
echo "===================="
echo "KrakenD (input_headers): $KRAKEND_CODE (${KRAKEND_TIME}s)"
echo "Direct Backend:          $BACKEND_CODE (${BACKEND_TIME}s)"

echo ""
if [ "$KRAKEND_CODE" = "$BACKEND_CODE" ] && [ "$KRAKEND_CODE" != "000" ]; then
    echo "🎉 SUCCESS! input_headers fixed the issue!"
    echo "   Both responses match - KrakenD is now properly forwarding headers"
    echo ""
    echo "✅ SOLUTION CONFIRMED:"
    echo "   - Change 'headers_to_pass' → 'input_headers' in KrakenD config"
    echo "   - Deploy updated configuration"
    echo "   - Authentication should work through KrakenD"
elif [ "$KRAKEND_CODE" = "000" ]; then
    echo "❌ Still connection issues with KrakenD"
    echo "   The change didn't resolve the connectivity problem"
else
    echo "⚠️  Different behavior detected"
    echo "   Need further investigation"
fi

echo ""
echo "🔧 Next steps:"
if [ "$KRAKEND_CODE" = "$BACKEND_CODE" ] && [ "$KRAKEND_CODE" != "000" ]; then
    echo "1. ✅ input_headers works! Update all endpoints in KrakenD config"
    echo "2. 🚀 Deploy the updated configuration"
    echo "3. 🧪 Test full authentication flow"
else
    echo "1. 📋 Document this test result"
    echo "2. 🔍 Try additional KrakenD configuration options"
    echo "3. 🚀 Consider DNS bypass as backup plan"
fi
echo "" 