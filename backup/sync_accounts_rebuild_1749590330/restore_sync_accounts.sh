#!/bin/bash
# SyncAccounts Implementation Restoration Script
# Created: 2025-06-10 21:25:30
# Purpose: Automatically restore SyncAccounts implementation after container rebuild

set -e  # Exit on any error

BACKUP_DIR=$(dirname "$0")
echo "🔄 SyncAccounts Implementation Restoration"
echo "=========================================="
echo "📁 Backup directory: $BACKUP_DIR"
echo ""

# Step 1: Create necessary directories
echo "📁 Creating Rails directories..."
mkdir -p app/controllers/api/v1/accounts/
mkdir -p lib/services/
mkdir -p lib/utilities/
echo "✅ Directories created"

# Step 2: Copy Rails application files
echo ""
echo "📋 Copying Rails application files..."

if [ -f "$BACKUP_DIR/controllers/sync_accounts_controller.rb" ]; then
    cp "$BACKUP_DIR/controllers/sync_accounts_controller.rb" app/controllers/api/v1/accounts/
    echo "✅ Controller copied"
else
    echo "❌ Controller file missing!"
    exit 1
fi

if [ -f "$BACKUP_DIR/services/sync_accounts_service.rb" ]; then
    cp "$BACKUP_DIR/services/sync_accounts_service.rb" lib/services/
    echo "✅ Service copied"
else
    echo "❌ Service file missing!"
    exit 1
fi

if [ -f "$BACKUP_DIR/utilities/logger.rb" ]; then
    cp "$BACKUP_DIR/utilities/logger.rb" lib/utilities/
    echo "✅ Utility copied"
else
    echo "❌ Utility file missing!"
    exit 1
fi

# Step 3: Routes configuration warning
echo ""
echo "⚠️  MANUAL STEP REQUIRED:"
echo "📝 Add the following to config/routes.rb inside the accounts scope:"
echo ""
echo "# Custom SyncAccounts service routes"
echo "# 2025-06-10 13:20:00 - Added SyncAccounts API for external system integration"  
echo "resources :sync_accounts, only: [:index, :create] do"
echo "  collection do" 
echo "    get :health"
echo "  end"
echo "end"
echo ""

# Step 4: Copy custom files
echo "📋 Copying custom documentation and scripts..."
if [ -d "$BACKUP_DIR/custom" ]; then
    cp -r "$BACKUP_DIR/custom"/* custom/ 2>/dev/null || mkdir -p custom/
    echo "✅ Custom files copied"
fi

# Step 5: Set permissions
echo ""
echo "🔐 Setting file permissions..."
chmod 644 app/controllers/api/v1/accounts/sync_accounts_controller.rb
chmod 644 lib/services/sync_accounts_service.rb  
chmod 644 lib/utilities/logger.rb
echo "✅ Permissions set"

# Step 6: Verification
echo ""
echo "🔍 Verification:"
echo "✅ Controller: $(ls -la app/controllers/api/v1/accounts/sync_accounts_controller.rb 2>/dev/null || echo 'MISSING')"
echo "✅ Service: $(ls -la lib/services/sync_accounts_service.rb 2>/dev/null || echo 'MISSING')"
echo "✅ Utility: $(ls -la lib/utilities/logger.rb 2>/dev/null || echo 'MISSING')"

echo ""
echo "🎉 SyncAccounts Implementation Restored!"
echo ""
echo "📝 Next Steps:"
echo "1. Manually add routes to config/routes.rb (see above)"
echo "2. Restart Rails application"
echo "3. Test: curl https://[DOMAIN]/api/v1/accounts/1/sync_accounts/health"
echo "4. Run: ruby custom/scripts/testing/test_sync_accounts_advanced.rb [URL]"
echo ""
echo "🔗 API Endpoints:"
echo "GET  /api/v1/accounts/{id}/sync_accounts        - Service info"
echo "POST /api/v1/accounts/{id}/sync_accounts        - Sync users"  
echo "GET  /api/v1/accounts/{id}/sync_accounts/health - Health check" 