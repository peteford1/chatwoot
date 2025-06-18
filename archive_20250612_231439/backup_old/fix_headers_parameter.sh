#!/bin/bash

echo "🔧 Fixing KrakenD Configuration - Replacing headers_to_pass with input_headers"
echo "=========================================================================="

# Backup the current configuration
echo "1️⃣ Creating backup..."
cp krakend.json "backup/krakend_headers_fix_$(date +%s).json"

# Replace all headers_to_pass with input_headers
echo "2️⃣ Replacing headers_to_pass with input_headers..."
sed -i.bak 's/"headers_to_pass":/"input_headers":/g' krakend.json

# Check if the replacement was successful
HEADERS_TO_PASS_COUNT=$(grep -c "headers_to_pass" krakend.json)
INPUT_HEADERS_COUNT=$(grep -c "input_headers" krakend.json)

echo ""
echo "📊 Results:"
echo "   headers_to_pass remaining: $HEADERS_TO_PASS_COUNT"
echo "   input_headers found: $INPUT_HEADERS_COUNT"

if [ "$HEADERS_TO_PASS_COUNT" -eq 0 ]; then
    echo "✅ SUCCESS! All headers_to_pass have been replaced with input_headers"
    echo ""
    echo "🧪 Now testing the configuration..."
    
    # Test the configuration
    if krakend check --config krakend.json; then
        echo "✅ Configuration is valid!"
        echo ""
        echo "🚀 Ready to test the API! The corrected configuration should now work."
        echo ""
        echo "📋 What was fixed:"
        echo "   - Changed all 'headers_to_pass' → 'input_headers'"
        echo "   - This matches KrakenD v2.10.0 official documentation"
        echo "   - Authentication headers should now forward properly"
        echo ""
        echo "🔍 Next steps:"
        echo "   1. Deploy this updated configuration to your KrakenD instance"
        echo "   2. Test authentication through KrakenD"
        echo "   3. Verify that profile API calls work through the domain"
    else
        echo "❌ Configuration validation failed! Please check the syntax."
        echo "   Restoring backup..."
        cp "backup/krakend_headers_fix_$(date +%s).json" krakend.json
    fi
else
    echo "⚠️  Warning: $HEADERS_TO_PASS_COUNT headers_to_pass entries still remain"
    echo "   Please check manually for any missed entries"
fi

echo ""
echo "🔗 Reference: https://www.krakend.io/docs/endpoints/parameter-forwarding/"
echo "   Official KrakenD docs confirm 'input_headers' is the correct parameter"
echo "" 