#!/bin/bash

# KrakenD Header Forwarding Test Script
# This script demonstrates the issue where KrakenD doesn't forward auth headers

echo "===========================================" 
echo "KrakenD Header Forwarding Issue Test"
echo "==========================================="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
KRAKEND_URL="https://voicelinkai.com"
BACKEND_URL="https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
DNS_RESOLVE="voicelinkai.com:443:104.21.79.119"

echo "Step 1: Authenticating through KrakenD..."
echo "=========================================="

# Get authentication tokens
auth_response=$(curl -s -X POST "${KRAKEND_URL}/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@voicelinkai.com","password":"SuperAdmin123!"}' \
  --resolve "${DNS_RESOLVE}" \
  -D /tmp/auth_headers.txt)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Authentication successful${NC}"
    
    # Extract tokens from headers
    ACCESS_TOKEN=$(grep -i "access-token:" /tmp/auth_headers.txt | cut -d' ' -f2 | tr -d '\r')
    CLIENT_TOKEN=$(grep -i "client:" /tmp/auth_headers.txt | cut -d' ' -f2 | tr -d '\r')
    USER_ID=$(grep -i "uid:" /tmp/auth_headers.txt | cut -d' ' -f2 | tr -d '\r')
    TOKEN_TYPE=$(grep -i "token-type:" /tmp/auth_headers.txt | cut -d' ' -f2 | tr -d '\r')
    EXPIRY_TIME=$(grep -i "expiry:" /tmp/auth_headers.txt | cut -d' ' -f2 | tr -d '\r')
    
    echo "Tokens received:"
    echo "  access-token: $ACCESS_TOKEN"
    echo "  client: $CLIENT_TOKEN"
    echo "  uid: $USER_ID"
    echo "  token-type: $TOKEN_TYPE"
    echo "  expiry: $EXPIRY_TIME"
else
    echo -e "${RED}✗ Authentication failed${NC}"
    exit 1
fi

echo
echo "Step 2: Testing profile endpoint through KrakenD..."
echo "=================================================="

# Test through KrakenD (this should FAIL)
krakend_response=$(curl -s -w "\nHTTP_STATUS:%{http_code}\nTIME:%{time_total}" \
  -X GET "${KRAKEND_URL}/api/v1/profile" \
  -H "access-token: $ACCESS_TOKEN" \
  -H "client: $CLIENT_TOKEN" \
  -H "uid: $USER_ID" \
  -H "token-type: $TOKEN_TYPE" \
  -H "expiry: $EXPIRY_TIME" \
  --resolve "${DNS_RESOLVE}")

krakend_status=$(echo "$krakend_response" | grep "HTTP_STATUS:" | cut -d':' -f2)
krakend_time=$(echo "$krakend_response" | grep "TIME:" | cut -d':' -f2)
krakend_body=$(echo "$krakend_response" | sed '/HTTP_STATUS:/,$d')

echo "KrakenD Request Details:"
echo "  URL: ${KRAKEND_URL}/api/v1/profile"
echo "  Headers sent:"
echo "    access-token: $ACCESS_TOKEN"
echo "    client: $CLIENT_TOKEN"
echo "    uid: $USER_ID"
echo "    token-type: $TOKEN_TYPE"
echo "    expiry: $EXPIRY_TIME"
echo
echo "KrakenD Response:"
echo "  Status: $krakend_status"
echo "  Time: ${krakend_time}s"
echo "  Body: $krakend_body"

if [ "$krakend_status" = "200" ]; then
    echo -e "${GREEN}✓ KrakenD request successful${NC}"
else
    echo -e "${RED}✗ KrakenD request failed with status $krakend_status${NC}"
fi

echo
echo "Step 3: Testing same request directly to backend..."
echo "================================================="

# Test direct to backend (this should SUCCEED)
backend_response=$(curl -s -w "\nHTTP_STATUS:%{http_code}\nTIME:%{time_total}" \
  -X GET "${BACKEND_URL}/api/v1/profile" \
  -H "access-token: $ACCESS_TOKEN" \
  -H "client: $CLIENT_TOKEN" \
  -H "uid: $USER_ID" \
  -H "token-type: $TOKEN_TYPE" \
  -H "expiry: $EXPIRY_TIME")

backend_status=$(echo "$backend_response" | grep "HTTP_STATUS:" | cut -d':' -f2)
backend_time=$(echo "$backend_response" | grep "TIME:" | cut -d':' -f2)
backend_body=$(echo "$backend_response" | sed '/HTTP_STATUS:/,$d')

echo "Direct Backend Request Details:"
echo "  URL: ${BACKEND_URL}/api/v1/profile"
echo "  Headers sent:"
echo "    access-token: $ACCESS_TOKEN"
echo "    client: $CLIENT_TOKEN"
echo "    uid: $USER_ID"
echo "    token-type: $TOKEN_TYPE"  
echo "    expiry: $EXPIRY_TIME"
echo
echo "Backend Response:"
echo "  Status: $backend_status"
echo "  Time: ${backend_time}s"
echo "  Body: $(echo "$backend_body" | head -c 100)..."

if [ "$backend_status" = "200" ]; then
    echo -e "${GREEN}✓ Direct backend request successful${NC}"
else
    echo -e "${RED}✗ Direct backend request failed with status $backend_status${NC}"
fi

echo
echo "=========================================="
echo "SUMMARY"
echo "=========================================="

if [ "$krakend_status" != "200" ] && [ "$backend_status" = "200" ]; then
    echo -e "${RED}ISSUE CONFIRMED:${NC}"
    echo "• Authentication works ✓"
    echo "• Direct backend access works ✓"
    echo "• KrakenD proxy fails ✗"
    echo
    echo -e "${YELLOW}ROOT CAUSE:${NC} KrakenD is not forwarding authentication headers"
    echo
    echo "Evidence:"
    echo "• Same exact headers"
    echo "• Same exact request"
    echo "• KrakenD status: $krakend_status (expected 200)"
    echo "• Backend status: $backend_status"
    echo "• Time difference suggests backend rejection (${krakend_time}s vs ${backend_time}s)"
    
    exit 1
elif [ "$krakend_status" = "200" ] && [ "$backend_status" = "200" ]; then
    echo -e "${GREEN}ISSUE RESOLVED:${NC}"
    echo "• Authentication works ✓"
    echo "• Direct backend access works ✓"
    echo "• KrakenD proxy works ✓"
    exit 0
else
    echo -e "${YELLOW}UNEXPECTED RESULT:${NC}"
    echo "• KrakenD status: $krakend_status"
    echo "• Backend status: $backend_status"
    echo "• This requires further investigation"
    
    echo
    echo "Debug information:"
    echo "Headers file content:"
    cat /tmp/auth_headers.txt
    exit 2
fi

# Cleanup
rm -f /tmp/auth_headers.txt 