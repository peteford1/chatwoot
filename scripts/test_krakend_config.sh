#!/bin/bash

# KrakenD Configuration Test Script
# Tests KrakenD configurations for different environments

set -e

echo "🔍 KrakenD Configuration Test Script"
echo "===================================="

# Check if KrakenD is installed
if ! command -v krakend &> /dev/null; then
    echo "❌ KrakenD not found. Please install KrakenD first."
    echo "   Visit: https://www.krakend.io/docs/overview/installing/"
    exit 1
fi

# Function to test a configuration file
test_config() {
    local env=$1
    local config_file="krakend/environments/${env}/krakend.json"
    
    echo ""
    echo "🧪 Testing ${env} environment configuration..."
    echo "   File: ${config_file}"
    
    if [ ! -f "$config_file" ]; then
        echo "❌ Configuration file not found: $config_file"
        return 1
    fi
    
    # Test configuration syntax
    if krakend check -c "$config_file" -t; then
        echo "✅ Configuration syntax is valid"
    else
        echo "❌ Configuration syntax is invalid"
        return 1
    fi
    
    # Show configuration summary
    echo "📋 Configuration Summary:"
    echo "   Name: $(jq -r '.name' "$config_file")"
    echo "   Port: $(jq -r '.port' "$config_file")"
    echo "   Endpoints: $(jq '.endpoints | length' "$config_file")"
    echo "   Timeout: $(jq -r '.timeout' "$config_file")"
    
    # List endpoints
    echo "🔗 Endpoints:"
    jq -r '.endpoints[] | "   \(.method) \(.endpoint)"' "$config_file"
    
    return 0
}

# Test all environments
environments=("dev" "test")
failed_tests=0

for env in "${environments[@]}"; do
    if ! test_config "$env"; then
        ((failed_tests++))
    fi
done

echo ""
echo "📊 Test Summary"
echo "==============="
echo "Total environments tested: ${#environments[@]}"
echo "Failed tests: $failed_tests"

if [ $failed_tests -eq 0 ]; then
    echo "✅ All configuration tests passed!"
    exit 0
else
    echo "❌ Some configuration tests failed!"
    exit 1
fi 