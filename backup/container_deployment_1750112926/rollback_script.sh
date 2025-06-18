#!/bin/bash

# Automated Rollback Script for chatwoot-backend-test
# Created: $(date '+%Y-%m-%d %H:%M:%S')

set -e  # Exit on any error

echo "🔄 Starting rollback of chatwoot-backend-test container..."
echo "📅 Original backup: $(date '+%Y-%m-%d %H:%M:%S')"

# Restore to the previous working revision
echo "⏪ Reverting to revision: chatwoot-backend-test--0000053"
az containerapp revision set-mode \
  --name chatwoot-backend-test \
  --resource-group SM-Test \
  --mode single \
  --revision-name chatwoot-backend-test--0000053

# Wait for the revision to become active
echo "⏳ Waiting for rollback to complete..."
sleep 30

# Verify the rollback
echo "✅ Verifying rollback..."
STATUS=$(az containerapp show --name chatwoot-backend-test --resource-group SM-Test --query 'properties.runningStatus' -o tsv)
echo "📊 Container Status: $STATUS"

# Test connectivity
echo "🌐 Testing connectivity..."
if curl -s --max-time 10 https://chatwoot-backend-test.calmmushroom-30b1c815.eastus.azurecontainerapps.io/ > /dev/null; then
    echo "✅ Connectivity test PASSED"
else
    echo "❌ Connectivity test FAILED"
    exit 1
fi

# Show current database configuration
echo "🗄️  Current database configuration:"
az containerapp show --name chatwoot-backend-test --resource-group SM-Test \
  --query 'properties.template.containers[0].env[?name==`DATABASE_URL`].value' -o tsv

echo ""
echo "🎉 Rollback completed successfully!"
echo "📋 The container is now restored to its previous state."
echo "⚠️  Note: This restored the WRONG configuration (chatwoot_production database)"
echo "💡 You may need to apply the correct shared database configuration again." 