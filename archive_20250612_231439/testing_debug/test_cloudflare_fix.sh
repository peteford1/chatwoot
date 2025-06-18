#!/bin/bash

echo "=== Testing Cloudflare Configuration ==="
echo

echo "1. Testing direct origin server:"
curl -s http://voicelinkai-gateway-instance-v32.calmmushroom-30b1c815.eastus.azurecontainerapps.io/health | jq .
echo

echo "2. Testing through Cloudflare (forced IP):"
curl -s --resolve voicelinkai.com:443:172.67.145.111 https://voicelinkai.com/health | head -5
echo

echo "3. Testing DNS resolution:"
dig voicelinkai.com +short
echo

echo "4. Testing normal HTTPS connection:"
curl -s -I https://voicelinkai.com/health | head -5
echo

echo "=== Test Complete ===" 