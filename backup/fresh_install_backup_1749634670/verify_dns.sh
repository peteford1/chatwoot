#!/bin/bash

echo "🔍 Checking DNS propagation..."
echo "================================"

echo "1. Checking TXT record for domain verification:"
dig +short TXT asuid.voicelinkai.com

echo -e "\n2. Checking A record for main domain:"
dig +short A voicelinkai.com

echo -e "\n3. Ready to add custom domain to Azure if both records are present!" 