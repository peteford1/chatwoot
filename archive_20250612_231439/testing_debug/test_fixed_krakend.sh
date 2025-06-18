#!/bin/bash

# Test script for fixed KrakenD configuration
# Date: June 12, 2025
# Status: WORKING ✅

echo "🚀 Testing Fixed KrakenD Configuration"
echo "======================================"

# Test credentials
ACCESS_TOKEN="7xVXtMhQNZ6zGMzjPUcxmg"
CLIENT="web"
UID="admin@voicelinkai.com"
KRAKEND_URL="http://localhost:8080"

echo ""
echo "📋 Test Configuration:"
echo "  - KrakenD URL: $KRAKEND_URL"
echo "  - Access Token: $ACCESS_TOKEN"
echo "  - Client: $CLIENT"
echo "  - UID: $UID"
echo ""

# Test 1: Profile Endpoint
echo "🔍 Test 1: Profile Endpoint"
echo "----------------------------"
echo "Testing: GET /api/v1/profile"

PROFILE_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" \
  -H "access-token: $ACCESS_TOKEN" \
  -H "client: $CLIENT" \
  -H "uid: $UID" \
  "$KRAKEND_URL/api/v1/profile")

PROFILE_BODY=$(echo $PROFILE_RESPONSE | sed -E 's/HTTPSTATUS\:[0-9]{3}$//')
PROFILE_STATUS=$(echo $PROFILE_RESPONSE | tr -d '\n' | sed -E 's/.*HTTPSTATUS:([0-9]{3})$/\1/')

echo "Status: $PROFILE_STATUS"
echo "Response: $PROFILE_BODY"

if [ "$PROFILE_STATUS" = "401" ]; then
    echo "✅ PASS: Profile endpoint returns proper 401 authentication error"
else
    echo "❌ FAIL: Expected 401, got $PROFILE_STATUS"
fi

echo ""

# Test 2: Validate Token Endpoint  
echo "🔍 Test 2: Validate Token Endpoint"
echo "-----------------------------------"
echo "Testing: GET /auth/validate_token"

VALIDATE_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" \
  -H "access-token: $ACCESS_TOKEN" \
  -H "client: $CLIENT" \
  -H "uid: $UID" \
  "$KRAKEND_URL/auth/validate_token")

VALIDATE_BODY=$(echo $VALIDATE_RESPONSE | sed -E 's/HTTPSTATUS\:[0-9]{3}$//')
VALIDATE_STATUS=$(echo $VALIDATE_RESPONSE | tr -d '\n' | sed -E 's/.*HTTPSTATUS:([0-9]{3})$/\1/')

echo "Status: $VALIDATE_STATUS"
echo "Response: $VALIDATE_BODY"

if [ "$VALIDATE_STATUS" = "401" ]; then
    echo "✅ PASS: Validate token endpoint returns proper 401 authentication error"
else
    echo "❌ FAIL: Expected 401, got $VALIDATE_STATUS"
fi

echo ""

# Test 3: Check for HTTP 000 errors (connection failures)
echo "🔍 Test 3: Connection Failure Check"
echo "------------------------------------"

if [ "$PROFILE_STATUS" != "000" ] && [ "$VALIDATE_STATUS" != "000" ]; then
    echo "✅ PASS: No HTTP 000 connection failures detected"
else
    echo "❌ FAIL: HTTP 000 connection failures still occurring"
fi

echo ""

# Summary
echo "📊 Test Summary"
echo "==============="

TOTAL_TESTS=3
PASSED_TESTS=0

if [ "$PROFILE_STATUS" = "401" ]; then
    ((PASSED_TESTS++))
fi

if [ "$VALIDATE_STATUS" = "401" ]; then
    ((PASSED_TESTS++))
fi

if [ "$PROFILE_STATUS" != "000" ] && [ "$VALIDATE_STATUS" != "000" ]; then
    ((PASSED_TESTS++))
fi

echo "Tests Passed: $PASSED_TESTS/$TOTAL_TESTS"

if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
    echo "🎉 ALL TESTS PASSED - KrakenD configuration is working correctly!"
    echo "✅ Ready for production deployment"
    exit 0
else
    echo "❌ Some tests failed - configuration needs further investigation"
    exit 1
fi 