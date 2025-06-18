#!/bin/bash

# Final KrakenD Header Forwarding Issue Demonstration
# This script proves that KrakenD is not forwarding authentication headers properly

echo "============================================================"
echo "🔍 FINAL KRAKEND HEADER FORWARDING ISSUE DEMONSTRATION"
echo "============================================================"
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AZURE_KRAKEND="https://voicelinkai.com"
BACKEND_URL="https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
DNS_RESOLVE="voicelinkai.com:443:104.21.79.119"

echo -e "${BLUE}Step 1: Getting fresh authentication tokens...${NC}"
echo "=================================================="

# Get fresh tokens
auth_response=$(curl -s -X POST "${AZURE_KRAKEND}/auth/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@voicelinkai.com","password":"SuperAdmin123!"}' \
  --resolve "${DNS_RESOLVE}" -D headers.tmp)

# Extract tokens from headers
ACCESS_TOKEN=$(grep -i "access-token:" headers.tmp | cut -d' ' -f2 | tr -d '\r')
CLIENT=$(grep -i "client:" headers.tmp | cut -d' ' -f2 | tr -d '\r')
UID=$(grep -i "uid:" headers.tmp | cut -d' ' -f2 | tr -d '\r')
TOKEN_TYPE=$(grep -i "token-type:" headers.tmp | cut -d' ' -f2 | tr -d '\r')
EXPIRY=$(grep -i "expiry:" headers.tmp | cut -d' ' -f2 | tr -d '\r')

echo "✅ Tokens obtained:"
echo "   access-token: ${ACCESS_TOKEN}"
echo "   client: ${CLIENT}"
echo "   uid: ${UID}"
echo "   token-type: ${TOKEN_TYPE}"
echo "   expiry: ${EXPIRY}"

rm -f headers.tmp

echo
echo -e "${BLUE}Step 2: Testing Direct Backend Access (Should Work)...${NC}"
echo "========================================================="

start_time=$(date +%s%3N)
backend_response=$(curl -s -w "HTTP_STATUS:%{http_code}\nTIME:%{time_total}" \
  -X GET "${BACKEND_URL}/api/v1/profile" \
  -H "access-token: ${ACCESS_TOKEN}" \
  -H "client: ${CLIENT}" \
  -H "uid: ${UID}" \
  -H "token-type: ${TOKEN_TYPE}" \
  -H "expiry: ${EXPIRY}")

backend_status=$(echo "$backend_response" | grep "HTTP_STATUS" | cut -d':' -f2)
backend_time=$(echo "$backend_response" | grep "TIME" | cut -d':' -f2)
backend_body=$(echo "$backend_response" | grep -v -E "(HTTP_STATUS|TIME)")

if [ "$backend_status" = "200" ]; then
  echo -e "${GREEN}✅ BACKEND TEST: SUCCESS${NC}"
  echo "   Status: $backend_status"
  echo "   Time: ${backend_time}s"
  echo "   Response: Profile data received successfully"
else
  echo -e "${RED}❌ BACKEND TEST: FAILED${NC}"
  echo "   Status: $backend_status"
  echo "   Response: $backend_body"
fi

echo
echo -e "${BLUE}Step 3: Testing Azure KrakenD Access (Will Fail)...${NC}"
echo "====================================================="

krakend_response=$(curl -s -w "HTTP_STATUS:%{http_code}\nTIME:%{time_total}" \
  -X GET "${AZURE_KRAKEND}/api/v1/profile" \
  -H "access-token: ${ACCESS_TOKEN}" \
  -H "client: ${CLIENT}" \
  -H "uid: ${UID}" \
  -H "token-type: ${TOKEN_TYPE}" \
  -H "expiry: ${EXPIRY}" \
  --resolve "${DNS_RESOLVE}")

krakend_status=$(echo "$krakend_response" | grep "HTTP_STATUS" | cut -d':' -f2)
krakend_time=$(echo "$krakend_response" | grep "TIME" | cut -d':' -f2)
krakend_body=$(echo "$krakend_response" | grep -v -E "(HTTP_STATUS|TIME)")

if [ "$krakend_status" = "200" ]; then
  echo -e "${GREEN}✅ KRAKEND TEST: SUCCESS${NC}"
  echo "   Status: $krakend_status"
  echo "   Time: ${krakend_time}s"
else
  echo -e "${RED}❌ KRAKEND TEST: FAILED${NC}"
  echo "   Status: $krakend_status"
  echo "   Time: ${krakend_time}s"
  echo "   Response: $krakend_body"
fi

echo
echo "============================================================"
echo -e "${YELLOW}🎯 ANALYSIS SUMMARY${NC}"
echo "============================================================"

if [ "$backend_status" = "200" ] && [ "$krakend_status" != "200" ]; then
  echo -e "${RED}❌ ISSUE CONFIRMED: KrakenD Header Forwarding Problem${NC}"
  echo
  echo "✅ Backend works with exact same headers (HTTP $backend_status)"
  echo "❌ KrakenD fails with same headers (HTTP $krakend_status)"
  echo
  echo "Response time comparison:"
  echo "  • Backend: ${backend_time}s (normal processing)"
  echo "  • KrakenD: ${krakend_time}s (fast rejection)"
  echo
  echo -e "${YELLOW}Conclusion:${NC} KrakenD is NOT properly forwarding authentication"
  echo "headers to the backend. The headers are being lost, transformed,"
  echo "or corrupted during the proxy process."
  echo
  echo -e "${BLUE}Next Steps:${NC}"
  echo "1. Enable KrakenD HTTP debug logging"
  echo "2. Test header case sensitivity"
  echo "3. Consider alternative API gateway"
  echo "4. Try KrakenD version downgrade"
elif [ "$backend_status" = "200" ] && [ "$krakend_status" = "200" ]; then
  echo -e "${GREEN}✅ ISSUE RESOLVED: Both backend and KrakenD working${NC}"
else
  echo -e "${YELLOW}⚠️  INCONCLUSIVE: Both tests failed${NC}"
  echo "Backend status: $backend_status"
  echo "KrakenD status: $krakend_status"
  echo "Check token validity and network connectivity"
fi

echo
echo "============================================================"
echo "🔗 Debug Files Created:"
echo "  • debug/krakend_header_forwarding_analysis_20250612.md"
echo "  • test_krakend_header_forwarding.sh" 
echo "  • final_krakend_test.sh (this script)"
echo "============================================================" 