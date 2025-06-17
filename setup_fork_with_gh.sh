#!/bin/bash

# VoiceLinkAI Fork Setup with GitHub CLI
# This script automates fork creation and deployment setup

echo "🚀 VoiceLinkAI Fork Setup with GitHub CLI"
echo "=========================================="

# Step 1: Check GitHub CLI authentication
echo "📋 Step 1: Checking GitHub CLI authentication..."
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ GitHub CLI not authenticated. Please run:"
    echo "   gh auth login"
    exit 1
fi
echo "✅ GitHub CLI authenticated"

# Step 2: Create fork if it doesn't exist
echo "📋 Step 2: Creating fork..."
FORK_URL=$(gh repo fork chatwoot/chatwoot --clone=false --remote=true --remote-name=fork 2>/dev/null || echo "fork_exists")

if [ "$FORK_URL" = "fork_exists" ]; then
    echo "⚠️  Fork might already exist, checking..."
    # Get the authenticated user
    USERNAME=$(gh api user --jq '.login')
    FORK_URL="https://github.com/$USERNAME/chatwoot"
    
    # Check if fork remote exists
    if git remote | grep -q "fork"; then
        echo "✅ Fork remote already configured"
    else
        echo "🔧 Adding fork remote..."
        git remote add fork "$FORK_URL.git"
    fi
else
    echo "✅ Fork created and remote added: $FORK_URL"
fi

# Step 3: Create deployment branch
echo "📋 Step 3: Creating deployment branch..."
BRANCH_NAME="voicelinkai-seeder-$(date +%s)"
git checkout -b "$BRANCH_NAME"
echo "✅ Created branch: $BRANCH_NAME"

# Step 4: Ensure our seeder files are committed
echo "📋 Step 4: Adding seeder files..."
git add scripts/deploy_test_env_seeder.rb simple_seeder.rb FORK_SETUP_GUIDE.md
git commit -m "Add VoiceLinkAI test environment seeder

- Production-ready seeder using API calls only
- Creates Platform App, Account, and Admin User  
- Includes comprehensive validation and error handling
- Generates tokens for VoiceLinkAI integration
- Manual execution guide included" || echo "✅ Files already committed"

# Step 5: Push to fork
echo "📋 Step 5: Pushing to fork..."
git push fork "$BRANCH_NAME"
echo "✅ Pushed to fork: $BRANCH_NAME"

# Step 6: Create a pull request (optional, for tracking)
echo "📋 Step 6: Creating pull request for tracking..."
PR_URL=$(gh pr create --repo fork --title "VoiceLinkAI Test Environment Seeder" --body "
# VoiceLinkAI Test Environment Seeder

This PR adds the production-ready seeder for VoiceLinkAI test environment setup.

## Features
- ✅ API-only approach (no direct database access)
- ✅ Platform App creation within test environment
- ✅ Account and admin user setup
- ✅ Comprehensive error handling and validation
- ✅ Environment-specific token generation

## Manual Execution Required
Since we're not using GitHub Actions, execute manually:

### Option A: Azure Portal Console
\`\`\`bash
cd /app
bundle exec rails runner scripts/deploy_test_env_seeder.rb
\`\`\`

### Option B: Rails Console
\`\`\`bash
cd /app && bundle exec rails console
# Then copy/paste content from simple_seeder.rb
\`\`\`

## Security
- Test environment schema isolation
- Environment-specific tokens
- Follows Chatwoot Platform API best practices
" --head "$BRANCH_NAME" 2>/dev/null || echo "PR creation skipped")

if [ "$PR_URL" != "PR creation skipped" ]; then
    echo "✅ Pull request created: $PR_URL"
else
    echo "ℹ️  Pull request creation skipped (may already exist)"
fi

# Step 7: Display execution instructions
echo ""
echo "🎯 FORK SETUP COMPLETE!"
echo "======================="
echo ""
echo "📁 Your fork: $FORK_URL"
echo "🌿 Branch: $BRANCH_NAME"
echo "📋 Files deployed:"
echo "   - scripts/deploy_test_env_seeder.rb"
echo "   - simple_seeder.rb"
echo "   - FORK_SETUP_GUIDE.md"
echo ""
echo "🚀 NEXT: Execute the seeder manually in Azure Portal"
echo "=================================================="
echo ""
echo "1. Go to Azure Portal → Container Apps → chatwoot-backend-test"
echo "2. Click 'Console' tab"
echo "3. Run one of these options:"
echo ""
echo "   Option A (Full Seeder):"
echo "   cd /app"
echo "   bundle exec rails runner scripts/deploy_test_env_seeder.rb"
echo ""
echo "   Option B (Simple Console):"
echo "   cd /app && bundle exec rails console"
echo "   # Then copy/paste from simple_seeder.rb"
echo ""
echo "📖 Full guide available in: FORK_SETUP_GUIDE.md"
echo ""
echo "✅ Ready to deploy VoiceLinkAI seeder to test environment!" 