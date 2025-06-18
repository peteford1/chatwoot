#!/bin/bash

echo "🔍 Testing Cloudflare SSL/TLS Propagation Status"
echo "=============================================="
echo "Configuration changed: 8 minutes ago"
echo "Expected propagation: 15-20 minutes total"
echo ""

echo "1. Testing HTTPS through Cloudflare:"
HTTPS_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://voicelinkai.com/api/v1/profile -H "access-token: test" --connect-timeout 10)
echo "   Result: HTTP $HTTPS_CODE"

if [ "$HTTPS_CODE" = "401" ]; then
    echo "   ✅ SUCCESS: SSL/TLS propagation complete!"
    echo "   🎉 HTTPS is working through Cloudflare"
elif [ "$HTTPS_CODE" = "525" ]; then
    echo "   ⏳ PROPAGATING: SSL handshake still failing"
    echo "   ⏰ Wait 5-10 more minutes and try again"
elif [ "$HTTPS_CODE" = "000" ]; then
    echo "   ⏳ PROPAGATING: Connection timeout/reset"
    echo "   ⏰ Wait 5-10 more minutes and try again"
else
    echo "   ❓ UNEXPECTED: HTTP $HTTPS_CODE"
fi

echo ""
echo "2. Testing HTTP through Cloudflare (should work):"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://voicelinkai.com/api/v1/profile -H "access-token: test")
echo "   Result: HTTP $HTTP_CODE"

if [ "$HTTP_CODE" = "401" ]; then
    echo "   ✅ HTTP working correctly"
else
    echo "   ❌ HTTP issue: $HTTP_CODE"
fi

echo ""
echo "3. Testing direct gateway (should work):"
DIRECT_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile -H "access-token: test")
echo "   Result: HTTP $DIRECT_CODE"

if [ "$DIRECT_CODE" = "401" ]; then
    echo "   ✅ Direct gateway working correctly"
else
    echo "   ❌ Direct gateway issue: $DIRECT_CODE"
fi

echo ""
echo "📋 Summary:"
if [ "$HTTPS_CODE" = "401" ]; then
    echo "🎉 COMPLETE: DNS update successful, SSL/TLS working!"
    echo "🌐 Your domain https://voicelinkai.com is fully operational"
else
    echo "⏳ IN PROGRESS: SSL/TLS configuration still propagating"
    echo "⏰ Run this script again in 5-10 minutes"
    echo "📞 Or test manually: curl -s -o /dev/null -w \"%{http_code}\" https://voicelinkai.com/api/v1/profile -H \"access-token: test\""
fi 