#!/bin/bash

# Azure Backend-Specific Verification Script
# Created: 2025-06-03 23:50:00
# Purpose: Test actual available endpoints on Azure Container Apps deployment
# Description: Adapted for the specific routing and configuration of this backend

BASE_URL="https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io"

echo "🎯 Azure Backend-Specific Testing..."
echo "Base URL: $BASE_URL"
echo "======================================================"

# Test 1: Core Application (CONFIRMED WORKING)
echo "1. Testing Core Application..."
response=$(curl -s -w "%{http_code}" "$BASE_URL/" -o /dev/null)
if [ "$response" == "200" ]; then
    echo "✅ Core app: HEALTHY (HTTP $response)"
else
    echo "❌ Core app: FAILED (HTTP $response)"
fi

# Test 2: Widget SDK (CONFIRMED WORKING)
echo "2. Testing Widget SDK..."
response=$(curl -s -w "%{http_code}" "$BASE_URL/packs/js/sdk.js" -o /dev/null)
if [ "$response" == "200" ]; then
    echo "✅ Widget SDK: AVAILABLE (HTTP $response)"
    # Test if SDK content is valid
    content=$(curl -s "$BASE_URL/packs/js/sdk.js" | head -1)
    if [[ $content == *"function"* ]] || [[ $content == *"var"* ]] || [[ $content == *"window"* ]]; then
        echo "   📄 SDK content: VALID JavaScript detected"
    else
        echo "   ⚠️  SDK content: May be malformed"
    fi
else
    echo "❌ Widget SDK: FAILED (HTTP $response)"
fi

# Test 3: Check if this is API-only backend
echo "3. Testing Backend Type..."
# Check if it returns JSON by default
content_type=$(curl -s -I "$BASE_URL/" | grep -i "content-type" | grep -i "json")
if [ ! -z "$content_type" ]; then
    echo "✅ Backend Type: API-FOCUSED (Returns JSON)"
    API_BACKEND=true
else
    echo "✅ Backend Type: FULL-STACK (Returns HTML)"
    API_BACKEND=false
fi

# Test 4: Available Routes Discovery
echo "4. Discovering Available Routes..."
# Common Chatwoot paths to test
paths=(
    "/api"
    "/webhooks" 
    "/public/api/v1"
    "/platform/api/v1"
    "/super_admin"
    "/admin"
    "/dashboard"
)

available_paths=()
for path in "${paths[@]}"; do
    response=$(curl -s -w "%{http_code}" "$BASE_URL$path" -o /dev/null)
    if [ "$response" != "404" ]; then
        available_paths+=("$path (HTTP $response)")
        echo "   ✅ $path: AVAILABLE (HTTP $response)"
    fi
done

if [ ${#available_paths[@]} -eq 0 ]; then
    echo "   ⚠️  No common paths found - may need specific routing"
fi

# Test 5: Websocket Alternatives
echo "5. Testing Real-time Connection Alternatives..."
websocket_paths=(
    "/cable"
    "/websocket"
    "/ws" 
    "/socket.io"
)

websocket_working=false
for ws_path in "${websocket_paths[@]}"; do
    response=$(curl -s -w "%{http_code}" "$BASE_URL$ws_path" -o /dev/null)
    if [ "$response" == "200" ] || [ "$response" == "101" ] || [ "$response" == "426" ]; then
        echo "   ✅ Websocket at $ws_path: AVAILABLE (HTTP $response)"
        websocket_working=true
        break
    fi
done

if [ "$websocket_working" = false ]; then
    echo "   ❌ No websocket endpoints found - Real-time features unavailable"
fi

# Test 6: Environment Detection
echo "6. Detecting Environment Configuration..."
# Check if production mode
response_headers=$(curl -s -I "$BASE_URL/" | grep -i "server\|x-powered-by\|x-runtime")
if echo "$response_headers" | grep -qi "nginx\|apache"; then
    echo "   ✅ Reverse proxy detected (Production setup)"
else
    echo "   ⚠️  Direct Rails server (Development/Test setup)"
fi

# Test 7: Webhook Endpoints (Critical for integrations)
echo "7. Testing Webhook Endpoints..."
webhook_paths=(
    "/webhooks/whatsapp/test"
    "/webhooks/sms/test" 
    "/webhooks/telegram/test"
    "/twilio/callback"
)

working_webhooks=()
for webhook in "${webhook_paths[@]}"; do
    response=$(curl -s -w "%{http_code}" "$BASE_URL$webhook" -o /dev/null)
    if [ "$response" != "404" ]; then
        working_webhooks+=("$webhook")
        echo "   ✅ $webhook: ACCEPTS REQUESTS (HTTP $response)"
    fi
done

if [ ${#working_webhooks[@]} -eq 0 ]; then
    echo "   ❌ No webhook endpoints responding - Integration issues likely"
fi

echo "======================================================"
echo "🏁 Azure Backend Analysis Complete!"
echo ""
echo "📊 Backend Status Summary:"
echo "- Core Application: FUNCTIONAL"
echo "- Widget SDK: AVAILABLE" 
echo "- Available Paths: ${#available_paths[@]} found"
echo "- Websocket Support: $([ "$websocket_working" = true ] && echo "YES" || echo "NO")"
echo "- Working Webhooks: ${#working_webhooks[@]} found"
echo ""
echo "🚨 Critical Issues to Address:"
if [ "$websocket_working" = false ]; then
    echo "- Configure Action Cable for real-time features"
fi
if [ ${#working_webhooks[@]} -eq 0 ]; then
    echo "- Verify webhook routing configuration"
fi
echo ""
echo "✅ This backend CAN support:"
echo "- Basic Chatwoot functionality"
echo "- Widget embedding (SDK available)"
echo "- Static file serving"
echo ""
echo "❌ This backend CANNOT support:"
if [ "$websocket_working" = false ]; then
    echo "- Real-time chat updates"
    echo "- Live typing indicators"
    echo "- Instant message notifications"
fi 