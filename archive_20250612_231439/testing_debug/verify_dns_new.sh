#!/bin/bash

echo "🔍 Verifying DNS Update for KrakenD Gateway..."
echo "=============================================="

echo "1. Checking current DNS resolution:"
echo "   Domain: voicelinkai.com"
dig +short A voicelinkai.com

echo -e "\n2. Testing KrakenD Gateway directly:"
echo "   Target: voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io"
GATEWAY_IP=$(dig +short voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io)
echo "   Gateway IP: $GATEWAY_IP"

echo -e "\n3. Testing HTTPS connectivity to domain:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://voicelinkai.com/api/v1/profile -H "access-token: test" -H "client: test" -H "uid: test")
echo "   https://voicelinkai.com/api/v1/profile"
echo "   Response Code: $HTTP_CODE"

if [ "$HTTP_CODE" = "401" ]; then
    echo "   ✅ SUCCESS: Gateway is working (401 = authentication required)"
elif [ "$HTTP_CODE" = "000" ]; then
    echo "   ❌ FAILED: Connection error (DNS not updated or gateway down)"
else
    echo "   ⚠️  UNEXPECTED: Got HTTP $HTTP_CODE (check gateway configuration)"
fi

echo -e "\n4. Testing direct gateway access:"
DIRECT_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io/api/v1/profile -H "access-token: test" -H "client: test" -H "uid: test")
echo "   Direct Gateway Response: $DIRECT_CODE"

if [ "$DIRECT_CODE" = "401" ]; then
    echo "   ✅ Gateway is healthy"
else
    echo "   ❌ Gateway issue detected"
fi

echo -e "\n5. DNS Propagation Status:"
if [ "$HTTP_CODE" = "$DIRECT_CODE" ] && [ "$HTTP_CODE" = "401" ]; then
    echo "   ✅ DNS UPDATE SUCCESSFUL!"
    echo "   🎉 voicelinkai.com is now routing through KrakenD Gateway"
elif [ "$HTTP_CODE" != "$DIRECT_CODE" ]; then
    echo "   ⏳ DNS still propagating..."
    echo "   💡 Wait 2-5 minutes and run this script again"
else
    echo "   ❌ Issue detected - check configuration"
fi

echo -e "\n6. Next Steps:"
echo "   - If successful: Test with valid authentication credentials"
echo "   - If failed: Check Cloudflare DNS settings or rollback"
echo "   - Monitor: https://voicelinkai.com/api/v1/profile should return 401" 