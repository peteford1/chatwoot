#!/bin/bash

echo "=== Testing Chatwoot API Flow ==="
echo

# Force DNS resolution through Cloudflare
RESOLVE_FLAG="--resolve voicelinkai.com:443:104.21.79.119"

echo "1. Testing Health Endpoint:"
curl $RESOLVE_FLAG -s https://voicelinkai.com/health | jq .
echo

echo "2. Testing Authentication:"
AUTH_RESPONSE=$(curl $RESOLVE_FLAG -X POST -H "Content-Type: application/json" \
  -d '{"email":"admin@voicelinkai.com","password":"SuperAdmin123!"}' \
  -s https://voicelinkai.com/auth/sign_in)

echo "$AUTH_RESPONSE" | jq .
echo

# Extract tokens from response
ACCESS_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.data.access_token')
USER_UID=$(echo "$AUTH_RESPONSE" | jq -r '.data.uid')

echo "3. Testing Profile Endpoint with Auth:"
curl $RESOLVE_FLAG -H "access-token: $ACCESS_TOKEN" -H "uid: $USER_UID" \
  -s https://voicelinkai.com/api/v1/profile | jq .
echo

echo "4. Testing Platform API (for SuperAdmin):"
curl $RESOLVE_FLAG -H "Authorization: Bearer $ACCESS_TOKEN" \
  -s https://voicelinkai.com/platform/api/v1/accounts | jq .
echo

echo "=== Test Complete ==="
echo "ACCESS_TOKEN: $ACCESS_TOKEN"
echo "USER_UID: $USER_UID" 