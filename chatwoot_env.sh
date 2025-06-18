#!/bin/bash
# Chatwoot Dynamic Environment Setup
# Source this file: source chatwoot_env.sh

echo "🚀 Loading Chatwoot environment for stable-api-admin@voicelinkai.com..."

export CHATWOOT_ACCOUNT_ID=1
export CHATWOOT_ACCOUNT_NAME="Voicelink"
export CHATWOOT_USER_ID=3
export CHATWOOT_USER_EMAIL="stable-api-admin@voicelinkai.com"
export CHATWOOT_USER_TOKEN="J8mwDmmcZbuYs6a672oT8TW6"

echo "   Account ID: $CHATWOOT_ACCOUNT_ID"
echo "   Account Name: $CHATWOOT_ACCOUNT_NAME"
echo "   User ID: $CHATWOOT_USER_ID"
echo "   User Email: $CHATWOOT_USER_EMAIL"
echo "   User Token: ${CHATWOOT_USER_TOKEN:0:15}..."
echo "✅ Chatwoot environment loaded!"
