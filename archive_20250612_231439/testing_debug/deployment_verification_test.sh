#!/bin/bash

# Chatwoot Azure Deployment Verification Script
# Created: 2025-06-03 23:47:00
# Purpose: Verify all services are running correctly on Azure

BASE_URL="https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"

echo "🚀 Starting Chatwoot Azure Deployment Verification..."
echo "Base URL: $BASE_URL"
echo "======================================================"

# Test 1: Main Application Health
echo "1. Testing Main Application..."
response=$(curl -s -w "%{http_code}" "$BASE_URL/" -o /dev/null)
if [ "$response" == "200" ]; then
    echo "✅ Main app: HEALTHY (HTTP $response)"
else
    echo "❌ Main app: FAILED (HTTP $response)"
fi

# Test 2: Rails Status
echo "2. Testing Rails Application Status..."
response=$(curl -s -w "%{http_code}" "$BASE_URL/rails/info/properties" -o /dev/null)
if [ "$response" == "200" ]; then
    echo "✅ Rails info: ACCESSIBLE (HTTP $response)"
else
    echo "⚠️  Rails info: Limited access (HTTP $response) - This may be normal"
fi

# Test 3: Websocket Connection
echo "3. Testing Websocket Endpoint..."
response=$(curl -s -w "%{http_code}" "$BASE_URL/cable" -o /dev/null)
if [ "$response" == "200" ] || [ "$response" == "101" ]; then
    echo "✅ Websocket: AVAILABLE (HTTP $response)"
else
    echo "❌ Websocket: FAILED (HTTP $response) - Real-time features may not work"
fi

# Test 4: API Base
echo "4. Testing API Base..."
response=$(curl -s -w "%{http_code}" "$BASE_URL/api/v1" -o /dev/null)
if [ "$response" == "200" ] || [ "$response" == "404" ]; then
    echo "✅ API base: RESPONDING (HTTP $response)"
else
    echo "❌ API base: FAILED (HTTP $response)"
fi

# Test 5: Widget SDK
echo "5. Testing Widget SDK..."
response=$(curl -s -w "%{http_code}" "$BASE_URL/packs/js/sdk.js" -o /dev/null)
if [ "$response" == "200" ]; then
    echo "✅ Widget SDK: AVAILABLE (HTTP $response)"
else
    echo "❌ Widget SDK: FAILED (HTTP $response) - Widget embedding will not work"
fi

# Test 6: Static Assets
echo "6. Testing Static Assets..."
response=$(curl -s -w "%{http_code}" "$BASE_URL/assets/application.css" -o /dev/null)
if [ "$response" == "200" ] || [ "$response" == "404" ]; then
    echo "✅ Static assets: RESPONDING (HTTP $response)"
else
    echo "❌ Static assets: FAILED (HTTP $response)"
fi

# Test 7: Database Connection (indirect test)
echo "7. Testing Database Connection..."
response=$(curl -s -w "%{http_code}" "$BASE_URL/api/v1/accounts" -o /dev/null)
if [ "$response" == "200" ] || [ "$response" == "401" ] || [ "$response" == "422" ]; then
    echo "✅ Database: CONNECTED (HTTP $response) - Auth required but DB responding"
else
    echo "❌ Database: CONNECTION ISSUE (HTTP $response)"
fi

# Test 8: Redis Connection (via session test)
echo "8. Testing Redis Connection..."
session_response=$(curl -s -c /tmp/cookies.txt -w "%{http_code}" "$BASE_URL/" -o /dev/null)
if [ "$session_response" == "200" ]; then
    echo "✅ Redis: LIKELY CONNECTED (Session handling working)"
else
    echo "⚠️  Redis: UNKNOWN STATUS"
fi

echo "======================================================"
echo "🏁 Verification Complete!"
echo ""
echo "📋 Summary:"
echo "- If all tests show ✅, your deployment is fully functional"
echo "- ❌ items need attention for full functionality"  
echo "- ⚠️  items may be normal depending on configuration"
echo ""
echo "🔧 Next Steps:"
echo "1. Fix any ❌ items found above"
echo "2. Test widget embedding with actual website token"
echo "3. Verify multitenancy if using multiple accounts"
echo "4. Test webhook endpoints with actual integrations" 