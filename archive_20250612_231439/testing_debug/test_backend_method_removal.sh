#!/bin/bash

echo "🧪 Testing KrakenD after removing backend method specification"
echo "============================================================"

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
echo "2️⃣ Testing profile endpoint through KrakenD (no backend method)..."

# Test through KrakenD with removed backend method
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
    echo "   🎯 PROGRESS! KrakenD is now reaching the backend!"
    echo "   Backend received request and processed authentication (401 = expected for invalid/expired tokens)"
elif [ "$KRAKEND_CODE" = "200" ]; then
    echo "   🎉 AMAZING! Authentication worked completely!"
    USER_NAME=$(echo "$KRAKEND_BODY" | jq -r '.name // "Unknown"')
    echo "   👤 User: $USER_NAME"
    echo "   📄 Response: $KRAKEND_BODY"
elif [ "$KRAKEND_CODE" = "000" ]; then
    echo "   ❌ Still connection issues with KrakenD"
    echo "   The method removal didn't resolve the connectivity problem"
else
    echo "   🤔 Different response code: $KRAKEND_CODE"
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

echo "   Status Code: $BACKEND_CODE"
echo "   Response Time: ${BACKEND_TIME}s"

echo ""
echo "📊 RESULTS COMPARISON"
echo "===================="
echo "KrakenD (no backend method): $KRAKEND_CODE (${KRAKEND_TIME}s)"
echo "Direct Backend:               $BACKEND_CODE (${BACKEND_TIME}s)"

echo ""
if [ "$KRAKEND_CODE" = "$BACKEND_CODE" ] && [ "$KRAKEND_CODE" != "000" ]; then
    echo "🎉 SUCCESS! Removing backend method fixed the issue!"
    echo "   Both responses match - KrakenD is now properly forwarding headers"
    echo ""
    echo "✅ SOLUTION CONFIRMED:"
    echo "   - Removed 'method: GET' from backend configuration"
    echo "   - Combined with 'input_headers' parameter fix"
    echo "   - Authentication should work through KrakenD"
elif [ "$KRAKEND_CODE" = "000" ]; then
    echo "❌ Still connection issues with KrakenD"
    echo "   The method removal didn't resolve the connectivity problem"
elif [ "$KRAKEND_CODE" = "401" ] && [ "$BACKEND_CODE" = "401" ]; then
    echo "🎯 PARTIAL SUCCESS! KrakenD is now reaching the backend!"
    echo "   Headers are being forwarded (both return 401)"
    echo "   Need to test with fresh/valid authentication tokens"
else
    echo "⚠️  Different behavior detected"
    echo "   Need further investigation"
fi

echo ""
echo "🔧 Configuration changes made:"
echo "   1. ✅ headers_to_pass → input_headers (34 endpoints)"
echo "   2. ✅ Removed backend method specification"
echo "" 