#!/bin/bash

# Deploy VoiceLinkAI Seeder to Your Fork (No GitHub Actions)
# This script helps you set up your fork and deploy manually

echo "🚀 Setting up VoiceLinkAI Seeder Deployment to Your Fork"
echo "========================================================"

# Step 1: Check if fork remote exists
echo "📋 Step 1: Checking git remotes..."
if git remote | grep -q "fork"; then
    echo "✅ Fork remote already exists"
    FORK_URL=$(git remote get-url fork)
    echo "Fork URL: $FORK_URL"
else
    echo "⚠️  No fork remote found. You need to:"
    echo "1. Create a fork of chatwoot/chatwoot on GitHub"
    echo "2. Add it as a remote: git remote add fork https://github.com/YOUR_USERNAME/chatwoot.git"
    echo "3. Run this script again"
    exit 1
fi

# Step 2: Create a deployment branch
echo "📋 Step 2: Creating deployment branch..."
BRANCH_NAME="voicelinkai-seeder-$(date +%s)"
git checkout -b "$BRANCH_NAME"
echo "✅ Created branch: $BRANCH_NAME"

# Step 3: Add our seeder files
echo "📋 Step 3: Ensuring seeder files are committed..."
git add scripts/deploy_test_env_seeder.rb simple_seeder.rb
git commit -m "Add VoiceLinkAI test environment seeder

- Production-ready seeder using API calls only
- Creates Platform App, Account, and Admin User
- Includes comprehensive validation and error handling
- Generates tokens for VoiceLinkAI integration" || echo "Files already committed"

# Step 4: Push to your fork
echo "📋 Step 4: Pushing to your fork..."
git push fork "$BRANCH_NAME"
echo "✅ Pushed to fork"

# Step 5: Instructions for manual execution
echo ""
echo "🎯 NEXT STEPS - Manual Execution:"
echo "================================="
echo ""
echo "Since we're not using GitHub Actions, you have two options:"
echo ""
echo "Option A: Execute via Azure Portal Console"
echo "1. Go to Azure Portal → Container Apps → chatwoot-backend-test"
echo "2. Go to Console tab"
echo "3. Run: cd /app"
echo "4. Run: bundle exec rails runner scripts/deploy_test_env_seeder.rb"
echo ""
echo "Option B: Execute simple seeder via Rails console"
echo "1. Go to Azure Portal → Container Apps → chatwoot-backend-test"
echo "2. Go to Console tab"
echo "3. Run: cd /app && bundle exec rails console"
echo "4. Copy and paste the content from simple_seeder.rb"
echo ""
echo "Option C: Use Azure CLI (if TTY issues are resolved)"
echo "1. Update your container with the latest code"
echo "2. Run: az containerapp exec --name chatwoot-backend-test --resource-group SM-Test --command \"cd /app && bundle exec rails runner scripts/deploy_test_env_seeder.rb\""
echo ""
echo "📁 Files ready for deployment:"
echo "- scripts/deploy_test_env_seeder.rb (Full production seeder)"
echo "- simple_seeder.rb (Simple version for manual console execution)"
echo ""
echo "🔗 Your fork branch: $BRANCH_NAME"
echo "🔗 Fork URL: $FORK_URL"
echo ""
echo "✅ Setup complete! Choose your preferred execution method above." 