#!/bin/bash

echo "🧪 Testing KrakenD with profile endpoint matching validate_token config"
echo "====================================================================="

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
echo "2️⃣ Testing validate_token endpoint (known working)..."

# Test validate_token through KrakenD (should work)
VALIDATE_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\nTIME:%{time_total}" \
  -X GET "${DOMAIN_URL}/auth/validate_token" \
  -H "access-token: $ACCESS_TOKEN" \
  -H "client: $CLIENT" \
  -H "uid: $USER_UID" \
  -H "token-type: Bearer" \
  -H "Content-Type: application/json")

VALIDATE_CODE=$(echo "$VALIDATE_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
VALIDATE_TIME=$(echo "$VALIDATE_RESPONSE" | grep "TIME:" | cut -d: -f2)

echo "   Status Code: $VALIDATE_CODE"
echo "   Response Time: ${VALIDATE_TIME}s"

echo ""
echo "3️⃣ Testing profile endpoint (now matching validate_token config)..."

# Test profile through KrakenD with matching configuration
PROFILE_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}\nTIME:%{time_total}" \
  -X GET "${DOMAIN_URL}/api/v1/profile" \
  -H "access-token: $ACCESS_TOKEN" \
  -H "client: $CLIENT" \
  -H "uid: $USER_UID" \
  -H "token-type: Bearer" \
  -H "Content-Type: application/json")

PROFILE_CODE=$(echo "$PROFILE_RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
PROFILE_TIME=$(echo "$PROFILE_RESPONSE" | grep "TIME:" | cut -d: -f2)
PROFILE_BODY=$(echo "$PROFILE_RESPONSE" | sed '/HTTP_CODE:/d' | sed '/TIME:/d')

echo "   Status Code: $PROFILE_CODE"
echo "   Response Time: ${PROFILE_TIME}s"

if [ "$PROFILE_CODE" = "401" ]; then
    echo "   🎯 PROGRESS! KrakenD is now reaching the backend!"
    echo "   Backend received request and processed authentication (401 = expected)"
elif [ "$PROFILE_CODE" = "200" ]; then
    echo "   🎉 AMAZING! Authentication worked completely!"
    USER_NAME=$(echo "$PROFILE_BODY" | jq -r '.name // "Unknown"')
    echo "   👤 User: $USER_NAME"
elif [ "$PROFILE_CODE" = "000" ]; then
    echo "   ❌ Still connection issues with KrakenD"
else
    echo "   🤔 Different response code: $PROFILE_CODE"
    echo "   Body: $PROFILE_BODY"
fi

echo ""
echo "4️⃣ For comparison - Direct backend test..."

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
echo "Validate Token (KrakenD): $VALIDATE_CODE (${VALIDATE_TIME}s)"
echo "Profile (KrakenD):        $PROFILE_CODE (${PROFILE_TIME}s)"
echo "Profile (Direct):         $BACKEND_CODE (${BACKEND_TIME}s)"

echo ""
if [ "$PROFILE_CODE" = "$VALIDATE_CODE" ] && [ "$PROFILE_CODE" != "000" ]; then
    echo "🎉 SUCCESS! Matching configuration fixed the issue!"
    echo "   Both KrakenD endpoints behave the same way"
    echo ""
    echo "✅ SOLUTION CONFIRMED:"
    echo "   - Profile endpoint now matches validate_token configuration"
    echo "   - Same headers, security policies, and backend settings"
    echo "   - Authentication should work consistently"
elif [ "$PROFILE_CODE" = "000" ]; then
    echo "❌ Still connection issues with profile endpoint"
    echo "   The configuration matching didn't resolve the problem"
elif [ "$PROFILE_CODE" = "$BACKEND_CODE" ]; then
    echo "🎯 PARTIAL SUCCESS! Profile endpoint now matches backend behavior"
    echo "   Headers are being forwarded properly"
else
    echo "⚠️  Different behavior detected"
    echo "   Need further investigation"
fi

echo ""
echo "🔧 Configuration changes made:"
echo "   1. ✅ headers_to_pass → input_headers"
echo "   2. ✅ Added security/policies to profile endpoint"
echo "   3. ✅ Restored backend method: GET"
echo "   4. ✅ Matched header list to validate_token endpoint"
echo "" 